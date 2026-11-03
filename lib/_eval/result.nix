# An eval part:   self = {
# A part is `_: st:`; `st` is the state of one eval: the names of every part, `root`, and the base helpers.
_: st:
let
  inherit (st)
    active
    agent
    attrNames
    b
    check
    checkOf
    clean
    concatMap
    context
    declaredIn
    deep
    elem
    errorsAll
    errWith
    explain
    facts
    filter
    first
    flakeFill
    floor
    fromEdge
    genAttrs
    graph
    head
    impact
    instances
    instNames
    intersectAttrs
    isList
    isRef
    kinds
    labels
    mapAttrs
    modules
    near
    nestedRef
    pathOf
    queryUntyped
    reads
    reduced
    refKind
    renderId
    root
    schema
    scopes
    secretFields
    shown
    static
    toList
    typeName
    undefined
    unknown
    untypedQueries
    withLean
    words
    yen
    ;
  paramsOf = ps: {
    required = filter (p: !(ps.${p} ? default)) (attrNames ps);
    optional = filter (p: ps.${p} ? default) (attrNames ps);
    types = mapAttrs (_: typeName) ps;
  };
  # q: the query's parameters (result.queries); ps: their types; vals: the args, refs resolved, defaults filled
  askTyped =
    n: args: q: ps:
    askVals n args q ps (mapAttrs (p: t: if args ? ${p} then fromEdge args.${p} else t.default) ps);
  askVals =
    n: args: q: ps: vals:
    askWith n args q ps vals (askChecks args q ps vals);
  # the first failure of each check, or null
  askChecks = args: q: ps: vals: {
    missing = first (a: !(args ? ${a})) q.required;
    extra = first (a: !elem a (q.required ++ q.optional)) (attrNames args);
    nested = first isList (
      concatMap (p: map (v: v.kind or null) (toList args.${p})) (attrNames args)
      ++ map (p: refKind ps.${p}) (attrNames ps)
    );
    lost = first (p: isRef args.${p} && vals.${p} == null) (attrNames args);
    bad = first (p: !checkOf ps.${p} vals.${p}) (attrNames ps);
  };
  askWith =
    n: args: q: ps: vals: c:
    if c.missing != null then
      errWith "ask" "query ${n}: missing ${c.missing}" {
        code = "missing-param";
        want = q.required;
        got = attrNames args;
      }
    else if c.extra != null then
      errWith "ask" "query ${n}: unknown parameter ${c.extra}" {
        code = "unknown-param";
        near = near c.extra (q.required ++ q.optional);
      }
    else if c.nested != null then
      nestedRef "ask" "ref" c.nested
    else if c.lost != null then
      unknown "ask" args.${c.lost}.name (instNames args.${c.lost}.kind) { code = "unknown-instance"; }
    else if c.bad != null then
      errWith "ask" "query ${n}: ${c.bad} wants ${q.types.${c.bad}}" {
        code = if refKind ps.${c.bad} != null then "ref" else "check";
        want = q.types.${c.bad};
        fix =
          if refKind ps.${c.bad} != null then
            "give ${c.bad} a ${refKind ps.${c.bad}} ref: yen.${refKind ps.${c.bad}}.<name>, or { kind; name; } from JSON"
          else
            "give ${c.bad} ${q.types.${c.bad}}";
      }
    else
      static.jsonSafe (yen.queries.${n}.answer (vals // { result = self; }));
  self = {
    # the scopes as answers state a secret field by its hash; the elements read the values
    #: result.scopes :: [ scope ] -- every scope, a secret field stated by its hash
    scopes = map (
      s:
      s // mapAttrs (f: v: shown s.kind f v) (intersectAttrs (genAttrs (secretFields s.kind) (_: null)) s)
    ) scopes;
    inherit
      active
      graph
      pathOf
      undefined
      declaredIn
      modules
      check
      facts
      schema
      explain
      context
      agent
      impact
      reads
      labels
      floor
      ;
    #: result.root :: module -- the module this result came from
    inherit root; # the module this result came from: a stored query can stage a change against it
    # every instance's field values, JSON-safe: for history diffs and agents
    #: result.data :: { kind = { name = fields; }; } -- every instance field value, JSON-safe, refs as kind:name
    data = mapAttrs (
      k: _:
      mapAttrs (
        n: i:
        static.jsonSafe (
          mapAttrs (f: v: if isRef v then "${renderId v.kind}:${v.name}" else shown k f v) (
            removeAttrs i (words "kind name")
          )
        )
      ) instances.${k}
    ) kinds;
    #: result.errors :: [ error ] -- every error record: where, what was expected, how to fix it
    errors = errorsAll;
    #: result.deep :: [ error ] -- the parts of typed values no frontier forced (list elements, attrset values), checked now, so it forces them; `checks.<system>.yen-lean` fails on them
    inherit deep;
    # L0: a fleet with an error, a violation, an undefined invariant or a forged rule head gives no outputs, and no
    # reduced sink values to build them from by hand (D13)
    #: result.reduced :: { sink = { scope id = value; }; } or null -- each sink reduced at each receiver; null when the fleet is not clean
    reduced = if clean then reduced else null;
    #: result.flake :: flake or { invalid-flake-errors = { errors; violations; incomplete; }; } -- the flake outputs; the reason instead when the fleet is not clean; with inputs.nixpkgs, always checks.<system>.yen-lean (lib.batteries.lean.verify)
    # its flake is the reason instead: a build finds no output, and `nix eval .#invalid-flake-errors` says why
    flake = withLean (
      if clean then
        flakeFill.ok
      else
        {
          invalid-flake-errors = {
            errors = errorsAll;
            inherit (check) violations incomplete;
          };
        }
    );
    # stored queries: `yen.queries.<name> = { params = { host = yen.kinds.host; }; answer = { host, result }: …; }`.
    # `result` is this eval result; each param has a type, and is optional when the type has a default. `ask name args`
    # never throws: an unknown query, a missing, unknown or ill-typed parameter is an error record.
    #: result.queries :: { name = { required; optional; types; }; } -- the stored queries of yen.queries, each with its parameters and their types
    queries = mapAttrs (_: q: paramsOf (q.params or { })) (b.removeAttrs yen.queries untypedQueries);
    #: result.ask :: name -> args -> answer -- a stored query by name; a ref from JSON is { kind; name; }, { kind; } or { aspect; }
    ask =
      n: args:
      if !(yen.queries ? ${n}) then
        unknown "ask" n (attrNames yen.queries) { code = "unknown-query"; }
      else if elem n untypedQueries then
        queryUntyped n
      else
        askTyped n args self.queries.${n} (yen.queries.${n}.params or { });
  };
in
{
  inherit
    self
    ;
}
