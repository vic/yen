# An eval part: labels by file path prefix (`yen.labels."agent/" = { trust = 1; }`): an aspect's label is the meet (the
# A part is `_: st:`; `st` is the state of one eval: the names of every part, `root`, and the base helpers.
_: st:
let
  inherit (st)
    any
    asked
    aspectMeta
    aspectNames
    aspects
    atErrors
    attrNames
    b
    check
    concatMap
    concatStringsSep
    datalog
    declaredIn
    declErrors
    declPath
    deep
    elem
    emitted
    errWith
    fieldAtoms
    filesOf
    fill
    filter
    floorOf
    foldl'
    found
    genAttrs
    gives
    graph
    hasInfix
    head
    inst
    instances
    instNames
    isAttrs
    isFunction
    isList
    isRef
    kindAt
    kindIds
    kindKeys
    kindNames
    kinds
    leanSystems
    leanVerify
    loaded
    loadErrors
    mapAttrs
    moduleSinks
    near
    optional
    orderErrors
    reduceErrors
    reduceModules
    refKind
    renderId
    requestErrors
    scopeKeys
    scopeMeta
    scopes
    sinkNames
    toList
    top
    treeErrors
    used
    words
    yen
    yenKeys
    ;
  # ── labels by file path prefix (`yen.labels."agent/" = { trust = 1; }`): an aspect's label is the meet (the
  # lowest trust) over the files that declare it; an element carries its aspect's label; `floor n` lists what is below.
  # A prefix is literal text after a `/`, never a regex. When the fleet has labels, an aspect no prefix covers has
  # trust 0: unknown provenance is never above a floor ──
  labelTable = top.labels or { };
  unlabeled = {
    trust = 0;
    prefix = null;
    file = null;
  };
  labelOf =
    n:
    foldl' (a: x: if a == null || (x.trust or 0) < (a.trust or 0) then x else a) null (
      concatMap (
        f:
        map (
          p:
          labelTable.${p}
          // {
            prefix = p;
            file = f;
          }
        ) (filter (p: hasInfix "/${p}" f) (attrNames labelTable))
      ) (filesOf n)
    );
  #: result.labels, yen.lib.labels :: { aspect = label; } -- the trust label of each aspect, from yen.labels
  labels =
    if labelTable == { } then
      { }
    else
      mapAttrs (n: _: if labelOf n == null then unlabeled else labelOf n) aspects;
  #: result.floor, yen.lib.floor :: trust -> [ edge ] -- the routed elements whose aspect trust is below trust
  floor = floorOf labels graph.edges;
  # a key yen does not read is an error, not a silent no-op: yen modules are not NixOS modules.
  # `from` is the module that declares the key
  keyErrors =
    let
      bad =
        from: path: known: xs:
        map (
          k:
          errWith (from k) "`${k}` is not a key yen reads here" {
            code = "unknown-key";
            path = path ++ [ k ];
            near = near k known;
            want = known;
            fix = "use one of the keys in `want`; yen modules are not NixOS modules";
          }
        ) (filter (k: !elem k known) xs);
      files = path: k: concatStringsSep ", " (declaredIn (path ++ [ k ]));
      # a kind and every kind nested in it read only kindKeys; `decl` is the path under `yen`
      kindKeyErrors =
        decl: d:
        if !isAttrs d then
          [ (notKind decl "a kind, an attrset of kind keys") ]
        else
          bad (files decl) ([ "yen" ] ++ decl) kindKeys (attrNames d)
          # `aspects` is an attrset of aspects, each an attrset
          ++ (
            if !isAttrs (d.aspects or { }) then
              [ (notKind (decl ++ [ "aspects" ]) "an attrset of aspects") ]
            else
              map (
                s:
                notKind (
                  decl
                  ++ [
                    "aspects"
                    s
                  ]
                ) "an aspect, an attrset"
              ) (filter (s: !isAttrs d.aspects.${s}) (attrNames (d.aspects or { })))
          )
          # #80: `sinks` is an attrset of sinks, each an attrset
          ++ (
            if !isAttrs (d.sinks or { }) then
              [ (notKind (decl ++ [ "sinks" ]) "an attrset of sinks") ]
            else
              map (
                s:
                notKind (
                  decl
                  ++ [
                    "sinks"
                    s
                  ]
                ) "a sink, an attrset"
              ) (filter (s: !isAttrs d.sinks.${s}) (attrNames (d.sinks or { })))
          )
          ++ (
            if !isAttrs (d.kinds or { }) then
              [ (notKind (decl ++ [ "kinds" ]) "an attrset of nested kinds") ]
            else
              concatMap (
                c:
                kindKeyErrors (
                  decl
                  ++ [
                    "kinds"
                    c
                  ]
                ) d.kinds.${c}
              ) (attrNames (d.kinds or { }))
          );
      notKind =
        decl: what:
        errWith (concatStringsSep ", " (declaredIn decl)) "yen.${concatStringsSep "." decl} is not ${what}"
          {
            code = "not-a-kind";
            path = [ "yen" ] ++ decl;
            fix = "write yen.${concatStringsSep "." decl} as ${what}";
          };
    in
    concatMap (
      n:
      map (
        c:
        errWith n.key "no module reads the sink `${c}`" {
          code = "unread-sink";
          path = [ c ];
          near = near c (attrNames asked);
          fix = "ask `${c}` as an arg of the module that reads it, or remove it";
        }
      ) (filter (c: !(asked ? ${c})) (gives n))
    ) (filter (n: n ? probe) found)
    ++ concatMap (c: (reduceModules c).errors) (
      filter (c: c != "yen" && used ? ${c}) (attrNames moduleSinks)
    )
    ++ bad (files [ ]) [ "yen" ] (yenKeys ++ kindNames) (attrNames top)
    ++ concatMap (k: kindKeyErrors [ "kinds" k ] top.kinds.${k}) kindNames
    ++ concatMap (
      n:
      bad (files [
        "aspects"
        n
      ]) [ "yen" "aspects" n ] (aspectMeta ++ sinkNames ++ [ "errors" ]) (attrNames aspects.${n})
    ) aspectNames
    ++ concatMap (
      c:
      bad (files [
        "sinks"
        c
      ]) [ "yen" "sinks" c ] (words "of reduce") (attrNames top.sinks.${c})
    ) (attrNames (top.sinks or { }));
  # `scope` and `sinks` are fixed args: a sink of that name could never be read
  reservedErrors =
    # #87: a name a fleet gives in `yen.aspects` never starts with `[`: that is the key of an owned aspect
    map
      (
        n:
        errWith "declarations"
          "aspect `${n}`: a name that starts with `[` is the key of an aspect an instance or a kind owns"
          {
            code = "reserved";
            path = [
              "aspects"
              n
            ];
            fix = "rename the aspect, or write it where it belongs: `yen.<kind>.<name>.aspects.<aspect>` or `yen.kinds.<kind>.aspects.<aspect>`";
          }
      )
      (
        filter (n: b.substring 0 1 n == "[") (
          concatMap (n: attrNames (n.mod.yen.aspects or { })) (filter (n: n ? mod) loaded)
        )
      )
    ++
      map
        (
          n:
          errWith "declarations" "sink `${n}`: the name is a fixed arg" {
            code = "reserved";
            fix = "rename the sink; `scope` and `sinks` are args of every element";
          }
        )
        (
          filter (n: elem n sinkNames) [
            "scope"
            "sinks"
          ]
        )
    # a field named like a key of a scope would read as that key, never as the field
    ++ concatMap (
      k:
      map (
        n:
        errWith "declarations" "field `${n}` of kind ${k}: the name is a key of every scope" {
          code = "reserved";
          path = [
            k
            n
          ];
          want = scopeKeys;
          fix = "rename the field; a scope already has ${concatStringsSep ", " scopeKeys}";
        }
      ) (filter (n: elem n scopeKeys) (attrNames (kinds.${k}.fields or { })))
    ) kindNames
    # an instance reads a nested kind's data at the key of its name: a scope key or a field there would shadow it
    ++ concatMap (
      id:
      concatMap (
        c:
        map
          (
            why:
            errWith "declarations" "nested kind `${c}` of kind ${renderId id}: ${why}" {
              code = "reserved";
              path = [ "yen" ] ++ declPath (toList id ++ [ c ]);
              fix = "rename the nested kind";
            }
          )
          (
            optional (elem c scopeMeta) "the name is a key of every scope"
            ++ optional ((kindAt id).fields or { } ? ${c}) "the kind has a field of that name"
            ++ optional (kinds ? ${c}) "a top kind has that name" # PROPOSED (c47 3a), not ruled by vic
          )
      ) (attrNames ((kindAt id).kinds or { }))
    ) kindIds
    # a sink `of` a nested kind would resolve refs in a table of top kinds only
    ++ concatMap (
      id:
      concatMap (d: map (nestedRef "declarations" "of") (filter isList [ (refKind (d.of or { })) ])) (
        b.attrValues ((kindAt id).sinks or { })
      )
    ) kindIds;
  # every error but the invariants': the `error` facts read these, so a rule never reads its own errors
  errorsFleet =
    loadErrors
    ++ reservedErrors
    ++ keyErrors
    ++ declErrors [ ]
    ++ concatMap (k: concatMap (n: (inst k [ k n ] [ ]).errors) (instNames k)) kindNames
    ++ treeErrors
    ++ atErrors
    ++ orderErrors
    ++ requestErrors
    ++ reduceErrors
    ++ emitted
    ++ map queryUntyped untypedQueries
    ++ optional (!(flakeFill ? ok)) flakeFill
    ++ concatMap (x: if x ? error then [ x.error ] else [ ]) fieldAtoms;
  errorsAll = errorsFleet ++ check.errors;
  # a query is { params; answer; }: a bare function has untyped parameters, so `ask` could not check them; no answer, nothing to ask
  untypedQueries = filter (n: !isFunction (yen.queries.${n}.answer or null)) (attrNames yen.queries);
  # c47 (GH #61): a ref to a nested kind is not supported yet; each use says so instead of a Nix throw
  nestedRef =
    from: code: id:
    errWith from
      "`yen.kinds.${renderId id}` is a nested kind: refs to nested kinds are not supported here yet"
      {
        inherit code;
        fix = "use a top kind here: a nested kind is reached only through its parent";
      };
  queryUntyped =
    n:
    errWith "queries" "query ${n} is not { params; answer; }: ask cannot check its parameters" {
      code = "query-untyped";
      fix = "write yen.queries.${n} = { params = { <name> = <type>; }; answer = { result, <name> }: …; }";
    };
  # a ref from JSON is its identity (refKey): { kind; name; } an instance (null when there is none), { kind; } a kind,
  # { aspect; } an aspect; a Nix ref resolves the same way, any other value stays
  fromEdge =
    v:
    if isList v then
      map fromEdge v
    else if !isAttrs v || v ? __kind || v ? __aspect then
      v
    else if isRef v then
      instances.${v.kind}.${v.name} or null
    else if attrNames v == [ "kind" ] then
      kinds.${v.kind} or v
    else if attrNames v == [ "aspect" ] then
      aspects.${v.aspect} or v
    else
      v;
  flakeFill = if top ? flake && scopes != [ ] then fill (head scopes) top.flake else { ok = null; };
  clean = errorsAll == [ ] && check.ok;
  # `checks.<system>.yen-lean` in every flake, clean or not, when `inputs.nixpkgs` is a module sink: the Lean checker
  # on the verdict, failing on a violation or an error. Not when a rule reads a relation decided by a Nix function:
  # Lean cannot decide it
  nixpkgsIn = if moduleSinks ? inputs then (reduceModules "inputs").value.nixpkgs or null else null;
  userExternals = map b.toJSON (filter (n: !(datalog.comparisons ? ${n})) check.lean.externals);
  leanDecides =
    !any (r: any (a: elem (head a) userExternals) ([ r.head ] ++ r.pos ++ r.neg)) check.lean.rules;
  withLean =
    o:
    if nixpkgsIn == null || !leanDecides || !isAttrs o then
      o
    else
      o
      // {
        checks =
          (o.checks or { })
          // genAttrs leanSystems (
            s:
            (o.checks.${s} or { })
            // {
              yen-lean = leanVerify {
                pkgs = nixpkgsIn.legacyPackages.${s};
                result = {
                  inherit check;
                  errors = errorsAll ++ deep;
                };
              };
            }
          );
      };
in
{
  inherit
    labelTable
    unlabeled
    labelOf
    labels
    floor
    keyErrors
    reservedErrors
    errorsFleet
    errorsAll
    untypedQueries
    nestedRef
    queryUntyped
    fromEdge
    flakeFill
    clean
    nixpkgsIn
    userExternals
    leanDecides
    withLean
    ;
}
