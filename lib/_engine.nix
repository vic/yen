# yen.nix: builtins only. A query language for configurations: a Cycle.js loop over nested scopes.
# No throws: an error is an emission. No merge, no module system: every read is a query on the files that answer it.
# Entry: `(import ./default.nix).lib.eval module`. A module is a path, a function or an attrset; `imports` nest; each key is a sink, each arg is a source.
self:
let
  inherit (self._prelude)
    all
    any
    attrNames
    b
    concatMap
    concatStringsSep
    datalog
    elem
    errWith
    filter
    floorOf
    genAttrs
    graphs
    groupBy
    head
    _impact
    isAttrs
    isFunction
    isList
    isPath
    isRef
    keySet
    krn
    length
    listToAttrs
    mapAttrs
    names
    near
    nest
    optional
    orNull
    rdf
    renderId
    static
    uniq
    words
    ;

  #: lib.eval :: module -> result -- evaluate a fleet module; the result answers every query
  # one fixpoint per eval: the state `st` holds the names every part of lib/_eval/ gives, the prelude, `root` and
  # `tools`; the answer is its `self`
  eval =
    root:
    (self._core.fix (
      st:
      b.foldl' (acc: p: acc // p st) (self._prelude // { inherit root tools; }) (b.attrValues self._eval)
    )).self;
  # grants that only narrow, by reference. A scope entry is a path [ { kind; name; } … ] (its scope and the scopes under
  # it) or an instance (every scope whose path holds it, and the scopes under them). A sink is a ref or { sink; }.
  # Identities hold only strings, so they compare as data. Two grants meet entry by entry: the deeper path when one
  # path holds the other, else both must hold ({ all }). There is no way to widen; a non-ref entry covers nothing.
  ident = x: { inherit (x) kind name; };
  entryOf =
    t:
    if isList t && t != [ ] && all isRef t then
      { path = map ident t; }
    else if isRef t then
      { instance = ident t; }
    else
      { invalid = t; };
  prefixOf = p: s: length p <= length s && b.genList (b.elemAt s) (length p) == p;
  covers =
    e: s:
    if e ? path then
      prefixOf e.path s
    else if e ? instance then
      elem e.instance s
    else if e ? all then
      all (x: covers x s) e.all
    else
      false;
  meet =
    e: f:
    if e ? invalid || f ? invalid then
      [ ]
    else if e == f then
      [ e ]
    else if e ? path && f ? path then
      if prefixOf e.path f.path then
        [ f ]
      else if prefixOf f.path e.path then
        [ e ]
      else
        [ ]
    else if e ? path && covers f e.path then
      [ e ]
    else if f ? path && covers e f.path then
      [ f ]
    else
      [
        {
          all = [
            e
            f
          ];
        }
      ];
  sinkOf = k: if isAttrs k then k.__sink or k.sink or null else null;
  grants = {
    #: lib.grant :: { scopes; sinks ? null; } -> grant -- where a change may reach, by reference: scope paths or instances, sink refs (null: every sink)
    grant =
      {
        scopes,
        sinks ? null,
      }:
      {
        scopes = map entryOf scopes;
        sinks = if sinks == null then null else map sinkOf sinks;
      };
    #: lib.narrow :: grant -> grant -> grant -- two grants met: the scopes both cover, the sinks both allow; never wider
    narrow = g: h: {
      scopes = uniq (concatMap (e: concatMap (meet e) h.scopes) g.scopes);
      sinks =
        if g.sinks == null then
          h.sinks
        else if h.sinks == null then
          g.sinks
        else
          filter (x: elem x h.sinks) g.sinks;
    };
    #: lib.allowed :: grant -> { to; sink; } -> bool -- the grant covers the scope path `to` and the sink (a ref or { sink; })
    allowed =
      g: e:
      any (p: covers p (map ident e.to)) g.scopes && (g.sinks == null || elem (sinkOf e.sink) g.sinks);
  };
  # data with no functions: it can be hashed, rendered as JSON and read back
  isData =
    v:
    if isList v then
      all isData v
    else if isAttrs v then
      !(v ? __functor) && all isData (b.attrValues v)
    else
      !isFunction v;
  # stage: an agent's change, in quarantine. Nothing changes; two evals compare. `ok` only when nothing new is wrong.
  #: lib.stage :: { base; change; rejected ? [ ]; grant ? null; by ? null; id ? null; baseResult ? eval base; } -> { ok; errors; violations; incomplete; refused; diff; labels; floor; lean; sha; render; } -- a change evaluated with the base and applied nowhere; ok only when nothing new is wrong
  stage =
    {
      base,
      change,
      rejected ? [ ],
      grant ? null,
      by ? null, # who submits it: { name; trust; }; the change's aspects carry this label (none: trust 0)
      id ? null, # the change's content hash, when the caller knows it (a program); else from a path or data
      baseResult ? eval base,
    }: # baseResult: the base already evaluated. The invariants always run: the law is not optional
    let
      changedResult = eval {
        imports = [
          base
          change
        ];
      };
      keyE = e: "${e.from}|${e.error}";
      keyG = e: "${e.sink}|${e.from}|${e.to}|${e.origin}";
      minus =
        k: xs: ys:
        let
          has = keySet (map k ys);
        in
        filter (x: !(has ? ${k x})) xs;
      delta = k: f: {
        added = minus k (f changedResult) (f baseResult);
        removed = minus k (f baseResult) (f changedResult);
      };
      ids = r: map (s: s.id) r.scopes;
      activeList =
        r:
        concatMap (n: map (id: "${n}@${id}") (filter (id: r.active.${n}.${id}) (attrNames r.active.${n}))) (
          attrNames r.active
        );
      sha =
        if id != null then
          id
        else if isPath change then
          b.hashFile "sha256" change
        else if isData change then
          b.hashString "sha256" (b.toJSON change)
        else
          null;
      diff = {
        scopes = delta (x: x) ids;
        edges = delta keyG (r: r.graph.edges);
        active = delta (x: x) activeList;
      };
      # what the change itself declares: no value comparison (reduced values can hold functions and cycles)
      declared = eval change;
      # .20 .13: every aspect the change declares carries its submitter's label, whatever file (or inline program op)
      # holds it, so a floor sees the agent
      labels =
        changedResult.labels
        //
          genAttrs
            (filter (
              n:
              declared.declaredIn [
                "aspects"
                n
              ] != [ ]
            ) (attrNames changedResult.active))
            (_: {
              trust = by.trust or 0;
              by = by.name or null;
              prefix = null;
              file = null;
            });
      # D14 exact: a change reaches what its seeds reach through reads, in either eval (lib/_impact.nix, vic/r-yen.md)
      declares = path: declared.declaredIn path != [ ];
      impactOf = _impact.impactOf;
      instT = k: n: {
        instance = k;
        name = n;
      };
      both = f: f baseResult ++ f changedResult;
      edgesBoth = both (r: r.graph.edges);
      outOf = e: {
        inherit (e) sink;
        at = e.to;
      };
      # origin "aspect n#1": an element of aspect n; "sink k": no aspect
      aspectOf = o: b.head (b.concatLists (orNull (b.match "aspect ([^#]*).*" o)) ++ [ null ]);
      kindAt = listToAttrs (
        map (s: {
          name = s.id;
          value = s.kind;
        }) (both (r: r.graph.scopes))
      );
      kindsBoth = names (both (r: attrNames r.schema.kinds));
      instancesOf = k: names (both (r: attrNames (r.data.${k} or { })));
      activePairs =
        r:
        concatMap (
          n:
          map (id: {
            aspect = n;
            at = id;
          }) (filter (id: r.active.${n}.${id}) (attrNames r.active.${n}))
        ) (attrNames r.active);
      activeDelta = delta b.toJSON activePairs;
      inBoth = filter (id: elem id (ids baseResult)) (ids changedResult);
      # S8: the same edges into one receiver, in another order (a list reduction sees the order)
      orderOf =
        r: other:
        mapAttrs (_: map keyG) (
          groupBy (e: b.toJSON (outOf e)) (
            filter (e: elem (keyG e) (map keyG other.graph.edges)) r.graph.edges
          )
        );
      ordered = orderOf baseResult changedResult;
      reordered = orderOf changedResult baseResult;
      seeds =
        map outOf (diff.edges.added ++ diff.edges.removed) # S1
        ++ concatMap (
          k:
          map (n: instT k n) (
            filter (
              n:
              declares [
                k
                n
              ]
            ) (instancesOf k)
          )
        ) kindsBoth # S2
        ++ map outOf (
          filter (
            e:
            aspectOf e.origin != null
            && declares [
              "aspects"
              (aspectOf e.origin)
            ]
          ) edgesBoth
        ) # S3
        ++ map (id: { data = id; }) (diff.scopes.added ++ diff.scopes.removed) # S4
        ++ concatMap (
          p: [ p ] ++ map outOf (filter (e: e.from == p.at && aspectOf e.origin == p.aspect) edgesBoth)
        ) (activeDelta.added ++ activeDelta.removed) # S5
        ++ concatMap (
          k:
          if
            declares [
              "kinds"
              k
            ]
          then
            map (id: { data = id; }) (filter (id: kindAt.${id} == k) (attrNames kindAt))
            ++ map (instT k) (instancesOf k)
            ++ map outOf (filter (e: kindAt.${e.to} == k || kindAt.${e.from} == k) edgesBoth)
          else
            [ ]
        ) kindsBoth # S6
        ++ map (id: { data = id; }) (
          filter (id: baseResult.reads.data.${id} != changedResult.reads.data.${id}) inBoth
        ) # S7: a scope's data, spawned or declared
        ++ map b.fromJSON (filter (k: ordered.${k} != reordered.${k} or [ ]) (attrNames ordered)); # S8
      dirty = impactOf {
        edges = both (r: r.reads.edges);
        whole = both (r: r.reads.whole);
        inherit seeds;
      };
      # helpers and queries are code every module can call: a change to them reaches every scope
      everywhere = any (k: declares [ k ]) (words "helpers queries");
      # a scope id of either eval as its path of identities: the grant compares paths, never id strings
      pathById = listToAttrs (
        concatMap
          (
            r:
            map (s: {
              name = s.id;
              value = r.pathOf s;
            }) r.scopes
          )
          [
            baseResult
            changedResult
          ]
      );
      allowedT =
        t:
        if t ? sink then
          grants.allowed grant {
            sink.sink = t.sink;
            to = pathById.${t.at};
          }
        else
          any (p: covers p pathById.${t.data or t.at}) grant.scopes;
      reached =
        if everywhere then
          filter (id: !any (p: covers p pathById.${id}) grant.scopes) (
            attrNames (keySet (ids baseResult ++ ids changedResult))
          )
        else
          names (map (t: t.data or t.at) (filter (t: !(t ? instance) && !allowedT t) dirty));
      outside =
        id:
        errWith "stage"
          "the change can reach ${
            concatStringsSep "/" (map (x: "${renderId x.kind} ${x.name}") pathById.${id})
          }, outside the grant"
          {
            code = "outside-grant";
            class = "authority";
            got = pathById.${id};
          };
      # a grant entry that is no ref covers nothing; say so, so a typo is never a silent refusal
      notScope = map (
        e:
        errWith "stage" "a grant scope is no ref" {
          code = "not-a-scope";
          class = "authority";
          got = e.invalid;
          fix = "grant { scopes = [ yen.<kind>.<name> or { kind; name; } or a path [ { kind; name; } … ] ]; }";
        }
      ) (filter (e: e ? invalid) (if grant == null then [ ] else grant.scopes));
      lawKeys = words "invariants relations labels flake";
      law = filter (k: declared.declaredIn [ k ] != [ ]) lawKeys;
      errors = minus keyE changedResult.errors baseResult.errors;
      violations = filter (a: !elem a baseResult.check.violations) changedResult.check.violations;
      incomplete = filter (a: !elem a baseResult.check.incomplete) changedResult.check.incomplete;
      refused =
        optional (sha != null && elem sha rejected) (
          errWith "stage" "this change was rejected before" {
            code = "rejected";
            class = "authority";
            got = sha;
          }
        )
        ++ map (
          k:
          errWith "stage" "the change declares `${k}`: the law is the owner's, never a change's" {
            code = "law-change";
            class = "authority";
            path = [ k ];
          }
        ) law
        # one refusal per scope, before or after the change, where it reaches outside the grant
        ++ map outside (if grant == null then [ ] else reached)
        ++ notScope;
    in
    {
      inherit
        errors
        refused
        sha
        violations
        incomplete
        diff
        labels
        ;
      floor = floorOf labels changedResult.graph.edges;
      # both verdicts for the Lean checker: `yen-cert-check --change base staged`
      lean = {
        base = baseResult.check.lean;
        staged = changedResult.check.lean;
      };
      ok = errors == [ ] && violations == [ ] && incomplete == [ ] && refused == [ ];
      render = if isData change then b.toJSON change else null; # read back with builtins.fromJSON
    };
  # field changes between two `data` answers: [ { path; old; new; } ], sorted by path
  #: lib.diffData :: data -> data -> [ { path; old; new; } ] -- the field changes between two data answers, sorted by path
  diffData =
    d0: d1:
    let
      keys = a: c: names (attrNames a ++ attrNames c);
      go =
        p: x: y:
        if isAttrs x && isAttrs y then
          concatMap (k: go (p ++ [ k ]) (x.${k} or null) (y.${k} or null)) (keys x y)
        else if x == y then
          [ ]
        else
          [
            {
              path = p;
              old = x;
              new = y;
            }
          ];
    in
    go [ ] d0 d1;
  # the fleet at a git revision (transaction time): `module` is the fleet module path inside the repository
  #: lib.asOf :: { url; rev; module; } -> result -- the fleet at a git revision
  asOf =
    {
      url,
      rev,
      module,
    }:
    eval (import ((b.fetchGit { inherit url rev; }) + "/${module}"));
  #: lib.history :: { url; revs; module; } -> [ { rev; errors; scopes; changes; } ] -- the fleet at each revision, with the field changes from the one before
  history =
    {
      url,
      revs,
      module,
    }:
    let
      r = b.elemAt (map (rev: asOf { inherit url rev module; }) revs); # one eval per revision
    in
    b.genList (i: {
      rev = b.elemAt revs i;
      errors = length (r i).errors;
      scopes = length (r i).scopes;
      changes = if i == 0 then [ ] else diffData (r (i - 1)).data (r i).data;
    }) (length revs);
  # without: the fleet with the files that declare `path` removed (coarse: a whole file goes; no engine hook)
  #: lib.without :: { files; path; args ? { }; } -> { dropped; result; } -- the fleet without the files that declare path; args = sinks the root gives
  without =
    {
      files,
      path,
      args ? { },
    }:
    let
      mk = fs: args // { imports = fs; };
      hit = (eval (mk files)).declaredIn path;
      keep = filter (f: !elem (toString f) hit) files;
    in
    {
      dropped = filter (f: elem (toString f) hit) files;
      result = eval (mk keep);
    };
  # change programs: a change as a list of data ops, so an agent can write, check, show and replay it.
  #   { op = "set"; path; value; }          one declaration path gets a value
  #   { op = "ref"; path; kind; name; }     one declaration path gets an instance ref
  #   { op = "place"; aspect; kind; name; } the aspect is also active at that instance
  #   { op = "new"; kind; name; fields; }   a new instance (a field value { ref = { kind; name; }; } is a ref)
  program = rec {
    #: lib.program.opErrors :: result -> index -> op -> [ error ] -- the errors of one program op against the fleet
    opErrors =
      r: i: o:
      let
        kinds = r.schema.kinds;
        k = head o.path;
        f = b.elemAt o.path 2;
        fs = attrNames (kinds.${k}.fields or { });
        fail = msg: x: [ (errWith "program[${toString i}]" msg ({ code = "program"; } // x)) ];
        noKind = if kinds ? ${o.kind or ""} then [ ] else fail "no kind ${o.kind or "?"}" { };
      in
      if !isAttrs o || !(o ? op) then
        fail "not an op" { want = "{ op = …; }"; }
      else if o.op == "set" || o.op == "ref" then
        if !(isList (o.path or null)) || o.path == [ ] then
          fail "path must be a non-empty list" { }
        else if !(kinds ? ${k}) then
          fail "no kind ${k}" { near = near k (attrNames kinds); }
        else if length o.path > 2 && !elem f fs then
          fail "kind ${k} has no field ${f}" { near = near f fs; }
        else if o.op == "ref" then
          noKind
        else
          [ ]
      else if o.op == "place" then
        if r.schema.aspects ? ${o.aspect or ""} then
          [ ]
        else
          fail "no aspect ${o.aspect or "?"}" { near = near (o.aspect or "") (attrNames r.schema.aspects); }
      else if o.op == "new" then
        noKind
      else
        fail "unknown op ${toString o.op}" {
          near = near (toString o.op) (words "set ref place new");
        };
    #: lib.program.validate :: result -> [ op ] -> [ error ] -- the errors of every op of a program
    validate = r: prog: b.concatLists (b.genList (i: opErrors r i (b.elemAt prog i)) (length prog));
    # the program as one yen module (a function: refs need `yen`)
    #: lib.program.toModule :: [ op ] -> module -- the program as one yen module
    toModule =
      prog:
      { yen, ... }:
      let
        refOf = x: if isAttrs x && x ? ref then yen.${x.ref.kind}.${x.ref.name} else x;
        one =
          o:
          if o.op == "set" then
            nest o.path o.value
          else if o.op == "ref" then
            nest o.path yen.${o.kind}.${o.name}
          else if o.op == "place" then
            { aspects.${o.aspect}.at = [ { inherit (o) kind name; } ]; }
          else
            { ${o.kind}.${o.name} = mapAttrs (_: refOf) (o.fields or { }); };
      in
      {
        imports = map (o: { yen = one o; }) prog;
      };
    #: lib.program.dryRun :: { base; prog; grant ? null; rejected ? [ ]; by ? null; result ? eval base; } -> stage answer // { valid; } -- validate the program, then stage it
    dryRun =
      {
        base,
        prog,
        grant ? null,
        rejected ? [ ],
        by ? null,
        result ? eval base,
      }:
      let
        errs = validate result prog;
        s = stage {
          inherit
            base
            grant
            rejected
            by
            ;
          baseResult = result;
          change = toModule prog;
          id = b.hashString "sha256" (b.toJSON prog); # a program is data: `rejected` matches it
        };
      in
      if errs != [ ] then
        {
          ok = false;
          valid = false;
          errors = errs;
        }
      else
        removeAttrs s [ "render" ] // { valid = true; };
  };
  # a change as data: set one declaration path (`change.set [ "host" "web-1" "port" ] 8080`)
  change = {
    #: lib.change.set :: [ name ] -> value -> module -- a module that gives one declaration path a value
    set = path: value: { yen = nest path value; };
  };
  # agent tools: the engine library outside an eval, and inside the fleet too
  tools = static // {
    inherit
      graphs
      rdf
      datalog
      krn
      stage
      change
      program
      diffData
      without
      ;
    inherit (grants) grant narrow allowed;
    inherit (self) batteries kits; # kits: ready-made modules a fleet imports
  };
in
{
  # the public names are listed in lib/api.nix
  inherit (grants) grant narrow allowed;
  inherit
    eval
    asOf
    history
    stage
    change
    program
    diffData
    without
    ;
  #: lib.mkFlake :: sinks -> module -> flake -- the flake outputs of the fleet, or { invalid-flake-errors } when it has an error or a violation.
  # `sinks` is a root module: each of its keys but `imports` and `yen` is a module sink, declared for you
  mkFlake =
    sinks: m:
    (eval {
      imports = [
        sinks
        {
          yen.sinks = mapAttrs (_: _: { }) (
            removeAttrs sinks [
              "imports"
              "yen"
            ]
          );
        }
        m
      ];
    }).flake;
}
