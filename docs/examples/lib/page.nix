# The API reference, extracted from the source: a line `#: <where>[, <where>…] :: <takes> -> <returns> -- <purpose>`
# above each definition in default.nix or lib/. A check fails when an API has no line, or a line names no API.
let
  b = builtins;
  # every .nix file of the engine: default.nix and lib/
  files =
    dir:
    b.concatLists (
      b.attrValues (
        b.mapAttrs (
          n: t:
          if t == "directory" then
            files (dir + "/${n}")
          else if b.match ".*\\.nix" n != null then
            [ (dir + "/${n}") ]
          else
            [ ]
        ) (b.readDir dir)
      )
    );
  # the GitHub source of a definition: the first line after its `#:` line that is not a comment
  githubBase = "https://github.com/vic/yen/blob/main/";
  linesOf = f: b.filter b.isString (b.split "\n" (b.readFile f));
  isComment = l: b.match " *#.*" l != null;
  # the line of the definition after line i: the first that is not a comment
  defAt =
    ls: i: if i + 1 < b.length ls && isComment (b.elemAt ls (i + 1)) then defAt ls (i + 1) else i + 1;
  # one entry per name of a `#:` line m; url is its definition on GitHub
  namesEntries =
    url: m: names:
    map (n: {
      name = n;
      value = {
        inherit names url;
        sig = b.elemAt m 2;
        does = b.elemAt m 3;
      };
    }) names;
  entriesAt =
    url: m:
    if m == null then [ ] else namesEntries url m (b.filter b.isString (b.split ", " (b.elemAt m 0)));
  fileDocsIn =
    rel: ls:
    b.concatLists (
      b.genList (
        i:
        entriesAt "${githubBase}${rel}#L${toString (defAt ls i + 1)}" (
          b.match " *#: ([^ ]+(, [^ ]+)*) :: (.*) -- (.*)" (b.elemAt ls i)
        )
      ) (b.length ls)
    );
  fileDocs =
    root: f: fileDocsIn (b.substring (b.stringLength root + 1) (b.stringLength f) f) (linesOf f);
  docsOf =
    root:
    b.listToAttrs (b.concatMap (fileDocs root) ([ (root + "/default.nix") ] ++ files (root + "/lib")));
  # the APIs: every function and type of `(import yen).lib`, nested sets walked; the fleet-bound extras of `yen.lib`; the
  # queries of an eval result, and those of `result.check`
  # a namespace: a set that is no function, no type (a type has `check`) and not empty
  isSet = v: b.isAttrs v && !(v ? __functor) && !(v ? check) && b.attrNames v != [ ];
  leaves =
    p: v:
    if isSet v then
      b.concatMap (n: leaves (p ++ [ n ]) v.${n}) (b.attrNames v)
    else
      [ (b.concatStringsSep "." p) ];
  # the APIs of an engine, from an eval result and the lib and facts that a module of a fleet sees
  apisWith = engine: result: inner: {
    lib = leaves [ "lib" ] engine;
    fleet = map (n: "yen.lib.${n}") (b.filter (n: !(engine ? ${n})) inner.lib);
    # the rule literals: the built-ins, then the ones each kind field and each relation gives
    rules = map (n: "yen.facts.${n}") inner.facts ++ [
      "yen.facts.<kind>.<field>"
      "yen.facts.<kind>.<field>.set"
      "yen.relations.<name>"
    ];
    result =
      map (n: "result.${n}") (b.attrNames result)
      ++ map (n: "result.check.${n}") (b.attrNames result.check);
  };
  apisOf =
    engine:
    apisWith engine
      (engine.eval {
        yen.kinds.top = { };
        yen.top.t = { };
      })
      (engine.eval (
        { yen, ... }:
        {
          yen.kinds.top.spawns.leaf = _: { };
          yen.kinds.leaf = { };
          yen.top.t = { };
          yen.flake =
            { ... }:
            {
              lib = b.attrNames yen.lib;
              facts = b.attrNames (removeAttrs yen.facts (b.attrNames yen.kinds));
            };
        }
      )).flake;
  cell = s: b.replaceStrings [ "|" ] [ "\\|" ] s;
  # plain MDX text: a brace or an angle bracket would read as JSX
  prose = s: b.replaceStrings [ "|" "<" ">" "{" "}" ] [ "\\|" "&lt;" "&gt;" "&#123;" "&#125;" ] s;
  under = p: b.filter (n: b.substring 0 (b.stringLength p) n == p);
  # the other names of one `#:` line: a fleet query is also a result query, so it is listed once, under `yen.lib`
  twins = d: n: b.filter (t: t != n) d.${n}.names;
  once = d: b.filter (n: under "yen.lib." (twins d n) == [ ]);
  table =
    docs: d: names:
    docs.table [ "API" "Takes and returns" "Purpose" ] (
      map (n: [
        (b.concatStringsSep ", " (
          [ "[`${n}`](${d.${n}.url})" ] ++ map (t: "`${t}`") (under "result." (twins d n))
        ))
        "`${cell d.${n}.sig}`"
        (prose d.${n}.does)
      ]) (b.filter (n: d ? ${n}) names)
    );
  # the namespaces of the engine lib: `lib.<s>` sets that are no function and no type
  subsOf =
    engine: b.filter (n: isSet engine.${n}) (b.attrNames engine);
  # the page, from the `#:` docs d and the apis
  pageOf =
    docs: engine: d: apis:
    [
      ''
        This page is extracted from the source when the docs are written. Each API has one line above its
        definition: `#: <where> :: <takes> -> <returns> -- <purpose>`. A check fails when an API has no line, so the
        page always lists every function. Each API name links to its definition on GitHub.

        Words in the signatures: *key value*, *out value*, *reduce* and *predicate* are in the [Glossary](/reference/glossary/).
        A *module* is a module of the target system; a *view* is `{ nodes; edges; }` for `mermaid.flowchart`; `succ` is a
        graph, an attrset from a node to its successors.

        ## Outside a fleet: `(import yen).lib`
      ''
      (table docs d (b.filter (n: b.length (b.filter b.isString (b.split "\\." n)) == 2) apis.lib))
    ]
    ++ b.concatMap (s: [
      "## `lib.${s}`"
      (table docs d (under "lib.${s}." apis.lib))
    ]) (subsOf engine)
    ++ [
      ''
        ## Inside a fleet: `yen.lib`

        Modules get the same lib, plus these predicates and queries bound to the fleet. They have no `result`: see
        [Inside the fleet](/query/queries/#inside-the-fleet). A query that an eval result also has is listed here
        once, with its `result` name next to it.
      ''
      (table docs d apis.fleet)
      ''
        ## Rules: `yen.facts` and `yen.relations`

        A rule is a function of its variables, `{ H }: { bad = H; pos = [ … ]; neg = [ … ]; }`. Its literals come
        from these references, never from strings. See [Invariants](/query/invariants/).
      ''
      (table docs d apis.rules)
      ''
        ## Queries of an eval result: `result = yen.lib.eval module`
      ''
      (table docs d (once d apis.result))
      (docs.links [
        {
          title = "Queries";
          href = "/query/queries/";
          description = "What each query answers, with examples.";
        }
        {
          title = "Error codes";
          href = "/reference/errors/";
          description = "Every error record yen can give.";
        }
      ])
    ];
  # every API has its line, and every line names an API
  checksOf = eq: d: apis: {
    undocumented = eq (b.filter (n: !(d ? ${n})) apis) [ ];
    stale = eq (b.filter (n: !(b.elem n apis)) (b.attrNames d)) [ ];
  };
in
{
  title = "API reference";
  description = "Every function and query of yen: where it is, what it takes, what it returns, and what it is for. Extracted from the source.";
  section = "reference";
  order = 2;

  body =
    {
      docs,
      engine,
      inputs,
      ...
    }:
    pageOf docs engine (docsOf inputs.yen.outPath) (apisOf engine);

  checks =
    {
      engine,
      inputs,
      eq,
      ...
    }:
    checksOf eq (docsOf inputs.yen.outPath) (b.concatLists (b.attrValues (apisOf engine)));
}
