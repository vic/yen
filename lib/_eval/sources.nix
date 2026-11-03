# An eval part: sources at a scope (Cycle isolateSource): the tree driver and one source per sink
# A part is `_: st:`; `st` is the state of one eval: the names of every part, `root`, and the base helpers.
_: st:
let
  inherit (st)
    any
    attrNames
    b
    concatMap
    concatStringsSep
    cycleOuts
    elem
    errWith
    filter
    first
    genAttrs
    holds
    instances
    intersectAttrs
    isAttrs
    isFunction
    isList
    isRef
    kindIds
    leafOf
    lib
    mapAttrs
    memo
    nestedRef
    orNull
    outAt
    receiverIn
    reduceAt
    requestKinds
    sinkNames
    toList
    uniq
    unsorted
    yen
    ;
  # ── sources at a scope (Cycle isolateSource): the tree driver and one source per sink ──
  isRen = n: n == "scope" || n == "sinks" || elem n kindArgs || elem n sinkNames; # `tree` is a cycle source, never an element arg
  # a kind arg is named by the kind's last id part (`user` for host.user); it reads the nearest ancestor scope of that kind
  kindArgs = uniq (map leafOf kindIds);
  nearestArg = n: s: first (x: leafOf x.kind == n) s.rup;
  nearest = k: s: first (x: x.kind == k) s.rup;
  # what a tree request answers at a scope: a list, empty when nothing answers (Cycle: no source, no emission)
  answer =
    s: q:
    if q ? nearest then
      orNull (nearest q.nearest.__kind s)
    else if q ? parent then
      orNull s.parent
    else if q ? children then
      [ (lib.children q.children s) ]
    else if q ? scopesOf then
      [ (lib.scopesOf q.scopesOf) ]
    else if q ? instances then
      [ (b.attrValues instances.${q.instances.__kind}) ]
    # the whole fleet: a reader of it (docs, diagrams) is reached by every change, and only it
    else if q ? graph then
      [ yen ] # instances with their data, and every structure query in yen.lib
    else
      [ (holds q.holds s) ];
  # a request is selected by itself: the same question on the same refs (kind, sink, aspect, instance), never a name
  refKey =
    v:
    if isAttrs v && v ? __kind then
      { kind = v.__kind; }
    else if isAttrs v && v ? __sink then
      { sink = v.__sink; }
    else if isAttrs v && v ? __aspect then
      { aspect = v.__aspect; }
    else if isRef v then
      { inherit (v) kind name; }
    else if isList v then
      map refKey v
    else if isFunction v then
      throw "tree request: a function predicate has no identity: use a kind, an aspect, an instance, or yen.lib combinators of them"
    else if isAttrs v then
      mapAttrs (_: refKey) (b.removeAttrs v [ "__functor" ])
    else
      v;
  reqKey = q: b.toJSON (mapAttrs (_: refKey) (intersectAttrs (genAttrs requestKinds (_: null)) q));
  sourcesAt =
    s: requests:
    {
      scope = s;
      tree.select = q: if any (r: known r && reqKey r == reqKey q) requests then answer s q else [ ];
    }
    // genAttrs sinkNames (
      n:
      let
        r = receiverIn n s.rup;
      in
      if r == null then [ ] else [ (memo.${n}.${r.id} or (reduceAt n r)).value ]
    ); # a receiver with no element yet reduces to its empty value
  known = q: !(q ? category) && any (k: q ? ${k}) requestKinds && !nestedAsk q; # no category: a request is selected by itself
  nestedAsk = q: isList (q.instances.__kind or null); # instances live in a table of top kinds only
  requestErrors = concatMap (
    s:
    concatMap (
      n:
      map (
        q:
        if nestedAsk q then
          nestedRef s.id "tree-request" q.instances.__kind
        else
          errWith s.id "aspect ${n}: unknown tree request" {
            code = "tree-request";
            fix = "ask one of ${concatStringsSep ", " requestKinds}, with no category, and select it by itself: tree.select request";
          }
      ) (filter (q: !known q) (toList ((outAt n s).tree or [ ])))
    ) (attrNames cycleOuts)
  ) unsorted;

in
{
  inherit
    isRen
    kindArgs
    nearestArg
    nearest
    answer
    refKey
    reqKey
    sourcesAt
    known
    nestedAsk
    requestErrors
    ;
}
