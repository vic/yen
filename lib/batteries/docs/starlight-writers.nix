#: lib.batteries.docs.starlight-writers :: { lib; repo; repoRoot; pagesAt; extra ? ; } -> dir -> writers -- Starlight markup writers for the page in `dir`
# The writers of a page's body: fences from the page's files, asides, tabs, steps, cards, tables, and diagrams from an
# eval result. `repo` is the repository URL, `repoRoot` its path, `pagesAt` the path of the pages directory in the
# repository (for the edit links). `lib` is read only by `value`. `extra` adds writers of the project: `dir: { name = ...; }`.
#   writers = docs.starlight-writers { inherit lib; repo = "https://github.com/me/proj"; repoRoot = ../..; pagesAt = "docs/pages"; };
#   (writers dir).note "Title" "body"
self:
{
  lib,
  repo,
  repoRoot,
  pagesAt,
  extra ? _: { },
}:
let
  b = builtins;
  mm = self.batteries.mermaid;
  inherit (self._core.helpers) uniq;
  last = xs: b.elemAt xs (b.length xs - 1);
  indexed = f: xs: b.genList (i: f i (b.elemAt xs i)) (b.length xs);
  join = b.concatStringsSep;
  words = xs: join " " (b.filter (x: x != "") xs);
  trim =
    s:
    if s != "" && b.substring (b.stringLength s - 1) 1 s == "\n" then
      b.substring 0 (b.stringLength s - 1) s
    else
      s;
  langs = {
    nix = "nix";
    json = "json";
    sh = "sh";
    md = "md";
  };
  langOf = p: langs.${last (b.filter b.isString (b.split "\\." p))} or "text";
  fence =
    lang: meta: text:
    "```${lang}${if meta != "" then " ${meta}" else ""}\n${trim text}\n```";
  pad = n: join "" (b.genList (_: " ") n);
  # continuation lines only
  indent =
    n: text:
    join "\n" (
      indexed (i: l: if i == 0 || l == "" then l else pad n + l) (b.filter b.isString (b.split "\n" text))
    );
  attr = v: b.replaceStrings [ "\"" ] [ "&quot;" ] v;
  # the fence marks of a text: one quoted "(n)" for each `# (n)` note in it, once each, in order
  notesOf =
    text:
    join " " (
      map (n: ''"(${n})"'') (uniq (map b.head (b.filter b.isList (b.split "# \\(([0-9]+)\\)" text))))
    );
  # every file of a page directory, as Starlight's FileTree list
  treeOf =
    dir: pre:
    b.concatLists (
      b.attrValues (
        b.mapAttrs (
          n: t:
          if t == "directory" then
            [ "${pre}- ${n}/" ] ++ treeOf (dir + "/${n}") "${pre}  "
          else
            [ "${pre}- ${n}" ]
        ) (removeAttrs (b.readDir dir) [ "page.nix" ])
      )
    );
  # a file of the page, as a titled code block. `meta` adds expressive-code marks: "{2-3}", "ins={4}"
  fileWith =
    dir: meta: p:
    fence (langOf p) (words [
      ''title="${p}"''
      meta
    ]) (b.readFile (dir + "/${p}"));
  aside =
    type: title: body:
    ":::${type}[${title}]\n${trim body}\n:::";
  tag =
    name: attrs: body:
    "<${name}${attrs}>\n\n${trim body}\n\n</${name}>";
  grid = items: "<CardGrid>\n${join "\n" items}\n</CardGrid>";
  mermaid = text: fence "mermaid" "" text;
in
dir:
{
  inherit
    aside
    mermaid
    notesOf # for a page's checks: the marks a file gets
    ;
  fileWith = fileWith dir;
  file = fileWith dir "";
  # a file of the repository, titled by its repository path: `repoFile "templates/minimal/flake.nix"`
  repoFile = p: fence (langOf p) ''title="${p}"'' (b.readFile (repoRoot + "/${p}"));
  # a file with `# (1)` notes in its comments: each `(n)` is marked, so the prose can say "(1)" and the reader finds the line
  fileNoted =
    meta: p:
    fileWith dir (words [
      meta
      (notesOf (b.readFile (dir + "/${p}")))
    ]) p;
  code = lang: text: fence lang "" text;
  nix = text: fence "nix" "" text;
  sh = text: fence "sh" ''frame="terminal"'' text;
  # a Nix value, printed: what a query answers (paths relative to the page)
  value =
    v:
    fence "nix" ''title="result"'' (
      b.replaceStrings [ "${toString dir}/" ] [ "" ] (lib.generators.toPretty { } v)
    );
  note = aside "note";
  tip = aside "tip";
  caution = aside "caution";
  tabs =
    items:
    join "\n" (
      [ "<Tabs>" ] ++ map (i: tag "TabItem" " label=\"${attr i.label}\"" i.body) items ++ [ "</Tabs>" ]
    );
  steps =
    items:
    "<Steps>\n\n${
      join "\n\n" (indexed (i: s: "${toString (i + 1)}. ${indent 3 (trim s)}") items)
    }\n\n</Steps>";
  cards =
    items:
    grid (map (c: tag "Card" " title=\"${attr c.title}\" icon=\"${c.icon or "star"}\"" c.body) items);
  links =
    items:
    grid (
      map (
        c:
        "<LinkCard title=\"${attr c.title}\" href=\"${c.href}\" description=\"${attr (c.description or "")}\" />"
      ) items
    );
  badge = text: variant: "<Badge text=\"${attr text}\" variant=\"${variant}\" />";
  table =
    head: rows:
    join "\n" (
      [
        "| ${join " | " head} |"
        "|${join "" (map (_: "---|") head)}"
      ]
      ++ map (r: "| ${join " | " r} |") rows
    );
  tree = "<FileTree>\n\n${join "\n" (treeOf dir "")}\n\n</FileTree>";
  # the scope tree of an eval result: each scope under its parent
  scopes = r: mermaid (mm.flowchart { direction = "TD"; } (mm.scopes { } r.graph));
  # routed elements: who gives what to whom (an element given at its own scope is a loop, left out)
  routes = r: mermaid (mm.flowchart { direction = "BT"; } (mm.routes r.graph));
  src = p: "${repo}/blob/main/${pagesAt}/${baseNameOf dir}/${p}";
}
// extra dir
