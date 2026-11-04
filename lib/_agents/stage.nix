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
    fix
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
    stageOut (
      fix (stageCtx {
        inherit
          base
          change
          rejected
          grant
          by
          id
          baseResult
          ;
      })
    );
  # the values of one stage, each computed once: `c` is this record
  stageCtx =
    {
      base,
      change,
      rejected,
      grant,
      by,
      id,
      baseResult,
    }:
    c: {
      inherit baseResult change;
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
        minusBy k xs (keySet (map k ys));
      delta = k: f: {
        added = c.minus k (f c.changedResult) (f baseResult);
        removed = c.minus k (f baseResult) (f c.changedResult);
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
        scopes = c.delta (x: x) c.ids;
        edges = c.delta c.keyG (r: r.graph.edges);
        active = c.delta (x: x) c.activeList;
      };
      # what the change itself declares: no value comparison (reduced values can hold functions and cycles)
      declared = eval change;
      # .20 .13: every aspect the change declares carries its submitter's label, whatever file (or inline program op)
      # holds it, so a floor sees the agent
      labels =
        c.changedResult.labels
        //
          genAttrs
            (filter (
              n:
              c.declared.declaredIn [
                "aspects"
                n
              ] != [ ]
            ) (attrNames c.changedResult.active))
            (_: {
              trust = by.trust or 0;
              by = by.name or null;
              prefix = null;
              file = null;
            });
      # D14 exact: a change reaches what its seeds reach through reads, in either eval (lib/_impact.nix, vic/r-yen.md)
      declares = path: c.declared.declaredIn path != [ ];
      impactOf = _impact.impactOf;
      instT = k: n: {
        instance = k;
        name = n;
      };
      both = f: f baseResult ++ f c.changedResult;
      edgesBoth = c.both (r: r.graph.edges);
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
        }) (c.both (r: r.graph.scopes))
      );
      kindsBoth = names (c.both (r: attrNames r.schema.kinds));
      instancesOf = k: names (c.both (r: attrNames (r.data.${k} or { })));
      activePairs =
        r:
        concatMap (
          n:
          map (id: {
            aspect = n;
            at = id;
          }) (filter (id: r.active.${n}.${id}) (attrNames r.active.${n}))
        ) (attrNames r.active);
      activeDelta = c.delta b.toJSON c.activePairs;
      inBoth = filter (id: elem id (c.ids baseResult)) (c.ids c.changedResult);
      # S8: the same edges into one receiver, in another order (a list reduction sees the order)
      orderOf =
        r: other:
        mapAttrs (_: map c.keyG) (
          groupBy (e: b.toJSON (c.outOf e)) (
            filter (e: elem (c.keyG e) (map c.keyG other.graph.edges)) r.graph.edges
          )
        );
      ordered = c.orderOf baseResult c.changedResult;
      reordered = c.orderOf c.changedResult baseResult;
      seeds =
        map c.outOf (c.diff.edges.added ++ c.diff.edges.removed) # S1
        ++ concatMap (
          k:
          map (n: c.instT k n) (
            filter (
              n:
              c.declares [
                k
                n
              ]
            ) (c.instancesOf k)
          )
        ) c.kindsBoth # S2
        ++ map c.outOf (
          filter (
            e:
            c.aspectOf e.origin != null
            && c.declares [
              "aspects"
              (c.aspectOf e.origin)
            ]
          ) c.edgesBoth
        ) # S3
        ++ map (id: { data = id; }) (c.diff.scopes.added ++ c.diff.scopes.removed) # S4
        ++ concatMap (
          p: [ p ] ++ map c.outOf (filter (e: e.from == p.at && c.aspectOf e.origin == p.aspect) c.edgesBoth)
        ) (c.activeDelta.added ++ c.activeDelta.removed) # S5
        ++ concatMap (
          k:
          if
            c.declares [
              "kinds"
              k
            ]
          then
            map (id: { data = id; }) (filter (id: c.kindAt.${id} == k) (attrNames c.kindAt))
            ++ map (c.instT k) (c.instancesOf k)
            ++ map c.outOf (filter (e: c.kindAt.${e.to} == k || c.kindAt.${e.from} == k) c.edgesBoth)
          else
            [ ]
        ) c.kindsBoth # S6
        ++ map (id: { data = id; }) (
          filter (id: baseResult.reads.data.${id} != c.changedResult.reads.data.${id}) c.inBoth
        ) # S7: a scope's data, spawned or c.declared
        ++ map b.fromJSON (filter (k: c.ordered.${k} != c.reordered.${k} or [ ]) (attrNames c.ordered)); # S8
      dirty = c.impactOf {
        edges = c.both (r: r.reads.edges);
        whole = c.both (r: r.reads.whole);
        inherit (c) seeds;
      };
      # helpers and queries are code every module can call: a change to them reaches every scope
      everywhere = any (k: c.declares [ k ]) (words "helpers queries");
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
            c.changedResult
          ]
      );
      allowedT =
        t:
        if t ? sink then
          grants.allowed grant {
            sink.sink = t.sink;
            to = c.pathById.${t.at};
          }
        else
          any (p: covers p c.pathById.${t.data or t.at}) grant.scopes;
      reached =
        if c.everywhere then
          filter (id: !any (p: covers p c.pathById.${id}) grant.scopes) (
            attrNames (keySet (c.ids baseResult ++ c.ids c.changedResult))
          )
        else
          names (map (t: t.data or t.at) (filter (t: !(t ? instance) && !c.allowedT t) c.dirty));
      outside =
        id:
        errWith "stage"
          "the change can reach ${
            concatStringsSep "/" (map (x: "${renderId x.kind} ${x.name}") c.pathById.${id})
          }, outside the grant"
          {
            code = "outside-grant";
            class = "authority";
            got = c.pathById.${id};
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
      law = filter (k: c.declared.declaredIn [ k ] != [ ]) c.lawKeys;
      errors = c.minus c.keyE c.changedResult.errors baseResult.errors;
      violations = filter (a: !elem a baseResult.check.violations) c.changedResult.check.violations;
      incomplete = filter (a: !elem a baseResult.check.incomplete) c.changedResult.check.incomplete;
      refused =
        optional (c.sha != null && elem c.sha rejected) (
          errWith "stage" "this change was rejected before" {
            code = "rejected";
            class = "authority";
            got = c.sha;
          }
        )
        ++ map (
          k:
          errWith "stage" "the change declares `${k}`: the law is the owner's, never a change's" {
            code = "law-change";
            class = "authority";
            path = [ k ];
          }
        ) c.law
        # one refusal per scope, before or after the change, where it reaches outside the grant
        ++ map c.outside (if grant == null then [ ] else c.reached)
        ++ c.notScope;
    };
  minusBy =
    k: xs: has:
    filter (x: !(has ? ${k x})) xs;
  stageOut = c: {
    inherit (c)
      errors
      refused
      sha
      violations
      incomplete
      diff
      labels
      ;
    floor = floorOf c.labels c.changedResult.graph.edges;
    # both verdicts for the Lean checker: `yen-cert-check --change base staged`
    lean = {
      base = c.baseResult.check.lean;
      staged = c.changedResult.check.lean;
    };
    ok = c.errors == [ ] && c.violations == [ ] && c.incomplete == [ ] && c.refused == [ ];
    render = if isData c.change then b.toJSON c.change else null; # read back with builtins.fromJSON
  };
in
{
  inherit
    isData
    stage
    ;
}
