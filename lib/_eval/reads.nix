# An eval part: reads: what each routed element reads, as tokens (lib/_impact.nix). A value reads the fleet only through its
# A part is `_: st:`; `st` is the state of one eval: the names of every part, `root`, and the base helpers.
_: st:
let
  inherit (st)
    any
    attrNames
    b
    byScope
    childrenAt
    concatMap
    elem
    filter
    fnArgs
    instances
    instNames
    isAttrs
    isFn
    isFunction
    isLeaf
    isList
    isPath
    isRef
    isRen
    isString
    isType
    kindArgs
    kindNames
    known
    lib
    mapAttrs
    nearest
    nearestArg
    optional
    orNull
    outAt
    receiverIn
    receivers
    refsOf
    routed
    scopeMeta
    scopes
    sinkNames
    sinkOf
    toList
    words
    ;
  # ── reads: what each routed element reads, as tokens (lib/_impact.nix). A value reads the fleet only through its
  # args and its cycle's sources, so these are all its reads: a staged change follows them, never more ──
  dataT = id: { data = id; };
  sinkT = n: id: {
    sink = n;
    at = id;
  };
  instT = k: n: {
    instance = k;
    name = n;
  };
  sinkAt = n: s: map (r: sinkT n r.id) (orNull (receiverIn n s.rup));
  # an aspect ref in a predicate reads where that aspect is active, at the scope and above it (`within`)
  activeAt =
    p: x:
    concatMap (
      a:
      map (y: {
        aspect = a;
        at = y.id;
      }) x.up
    ) (refsOf p);
  formalReads =
    s: v:
    if !isFn v then
      [ ]
    else
      concatMap (
        n:
        if n == "scope" then
          [ (dataT s.id) ]
        else if n == "sinks" then
          concatMap (k: sinkAt k s) sinkNames
        else if elem n kindArgs then
          map (x: dataT x.id) (orNull (nearestArg n s))
        else
          sinkAt n s
      ) (filter isRen (attrNames (fnArgs v)));
  requestReads =
    s: q:
    if q ? nearest then
      map (x: dataT x.id) (orNull (nearest q.nearest.__kind s))
    else if q ? parent then
      map (x: dataT x.id) (orNull s.parent)
    else if q ? children then
      concatMap (c: [ (dataT c.id) ] ++ activeAt q.children c) (childrenAt.${s.id} or [ ])
    else if q ? scopesOf then
      map (x: dataT x.id) (lib.scopesOf q.scopesOf)
    else if q ? instances then
      map (instT q.instances.__kind) (instNames q.instances.__kind)
    else if q ? graph then
      [ ]
    else
      [ (dataT s.id) ] ++ activeAt q.holds s;
  requestsOf = e: filter known (toList ((outAt e.aspect e.from).tree or [ ]));
  isWhole = e: e ? raw && any (q: q ? graph) (requestsOf e); # a whole-fleet reader: every change reaches it
  edgeReads =
    e:
    formalReads e.from e.value
    ++ (
      if e ? raw then
        [ (dataT e.from.id) ]
        ++ concatMap (k: sinkAt k e.from) sinkNames
        ++ concatMap (requestReads e.from) (requestsOf e)
      else
        [ ]
    );
  # a scope's own data, with refs cut to their identity: its fingerprint, the instances it holds, and functions
  walk =
    v:
    if isRef v && isString v.kind && isString v.name && (instances.${v.kind} or { }) ? ${v.name} then
      {
        fp.__ref = [
          v.kind
          v.name
        ];
        refs = [ (instT v.kind v.name) ];
        opaque = false;
      }
    else if isAttrs v && v ? __here then
      {
        fp.__scope = v.id;
        refs = [ (dataT v.id) ];
        opaque = false;
      } # a scope: its data is that scope's token (its `up` holds itself)
    else if isFunction v || isAttrs v && (isLeaf v || v ? outPath) then
      {
        fp = null;
        refs = [ ];
        opaque = true;
      }
    else if isList v then
      walkList (map walk v)
    else if isAttrs v then
      walkAttrs (mapAttrs (_: walk) v)
    else
      {
        fp = if isPath v then toString v else v;
        refs = [ ];
        opaque = false;
      };
  many = ws: {
    refs = concatMap (w: w.refs) ws;
    opaque = any (w: w.opaque) ws;
  };
  walkList = ws: many ws // { fp = map (w: w.fp) ws; };
  walkAttrs = ws: many (b.attrValues ws) // { fp = mapAttrs (_: w: w.fp) ws; };
  walks = byScope (s: walk (removeAttrs s scopeMeta)) scopes;
  #: result.reads :: { edges; whole; data; } -- what every element, scope and instance reads, as tokens; whole: reached by any change; data: each scope's data by its sha256
  reads = {
    edges =
      map (e: {
        out = sinkT e.key e.to.id;
        reads = edgeReads e;
      }) (filter (e: !isWhole e) routed)
      # a scope's record holds its parent's (`up`), its instance and the instances it refs
      ++ map (s: {
        out = dataT s.id;
        reads = [ (instT s.kind s.name) ] ++ walks.${s.id}.refs ++ map (p: dataT p.id) (orNull s.parent);
      }) scopes
      ++ concatMap (
        k:
        map (n: {
          out = instT k n;
          reads = (walk (removeAttrs instances.${k}.${n} (words "kind name"))).refs;
        }) (instNames k)
      ) kindNames
      # a sink `of` a kind reduces the instances its refs name
      ++ concatMap (n: concatMap (r: ofReads n r (sinkOf r n)) (receivers n)) sinkNames;
    whole =
      map (e: sinkT e.key e.to.id) (filter isWhole routed)
      ++ map (s: dataT s.id) (filter (s: walks.${s.id}.opaque) scopes); # a function in the data: no fingerprint
    data = mapAttrs (_: w: b.hashString "sha256" (b.toJSON w.fp)) walks; # by hash: a secret field stays unstated
  };
  # a sink `of` a kind reads every instance of that kind
  ofReads =
    n: r: d:
    optional (d ? of && isType d.of && isString (d.of.__kind or null)) {
      out = sinkT n r.id;
      reads = map (instT d.of.__kind) (instNames d.of.__kind);
    };
in
{
  inherit
    dataT
    sinkT
    instT
    sinkAt
    activeAt
    formalReads
    requestReads
    requestsOf
    isWhole
    edgeReads
    walk
    walks
    reads
    ;
}
