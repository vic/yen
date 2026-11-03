self:
let
  inherit (self._prelude)
    all
    any
    attrNames
    b
    concatMap
    concatStringsSep
    elem
    errWith
    filter
    floorOf
    genAttrs
    groupBy
    _impact
    isAttrs
    isFunction
    isList
    isPath
    keySet
    listToAttrs
    mapAttrs
    names
    optional
    orNull
    renderId
    words
    ;
  inherit (self._engine) eval;
  inherit (self._agents.grants) covers grants;
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
in
{
  inherit
    isData
    stage
    ;
}
