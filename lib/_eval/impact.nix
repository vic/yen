# An eval part: impact: the scopes an element of `id` reaches, transitively over routed elements, by depth
# A part is `_: st:`; `st` is the state of one eval: the names of every part, `root`, and the base helpers.
_: st:
let
  inherit (st)
    b
    byId
    cut
    elem
    filter
    genericClosure
    graph
    head
    isAttrs
    isString
    near
    pathOf
    scopeIn
    sinkNames
    unknown
    ;
  # ── impact: the scopes an element of `id` reaches, transitively over routed elements, by depth ──
  #: result.impact :: scope -> { hops ? ; sinks ? ; max ? ; } -> by depth -- the scopes an element of the scope reaches, transitively; a sink is a ref or { sink; }
  impact =
    t:
    {
      hops ? 3,
      sinks ? null,
      max ? 50,
    }:
    impactAt (scopeIn "impact" t) hops (sinkNamesOf sinks) max;
  # a sink by reference: yen.kinds.<kind>.sinks.<sink>, or { sink; } from outside the fleet; null: every sink
  sinkNamesOf =
    sinks:
    if sinks == null then
      null
    else
      map (k: if isAttrs k then k.__sink or k.sink or null else null) sinks;
  unknownSinks =
    names: if names == null then [ ] else filter (k: !isString k || !elem k sinkNames) names;
  impactAt =
    sc: hops: names: max:
    if !(sc ? ok) then
      sc
    else if unknownSinks names != [ ] then
      unknownSink (if isString (head (unknownSinks names)) then head (unknownSinks names) else "")
    else
      depthsOf hops (cut max (reachedFrom sc.ok.id hops names));
  unknownSink =
    k:
    unknown "impact" k sinkNames { code = "unknown-sink"; }
    // {
      near = map (k: { sink = k; }) (near k sinkNames);
    };
  depthsOf = hops: c: {
    reached = c.items;
    inherit (c) truncated;
    inherit hops;
  };
  step = names: from: filter (e: e.from == from && (names == null || elem e.sink names)) graph.edges;
  # every scope reached from id in hops or fewer, nearest first, then by id
  reachedFrom =
    id: hops: names:
    map
      (x: {
        scope = pathOf byId.${x.key};
        inherit (x) depth;
        via.sink = x.via;
      })
      (
        b.sort (p: q: p.depth < q.depth || p.depth == q.depth && p.key < q.key) (
          filter (x: x.key != id) (genericClosure {
            startSet = [
              {
                key = id;
                depth = 0;
              }
            ];
            operator =
              x:
              if x.depth >= hops then
                [ ]
              else
                map (e: {
                  key = e.to;
                  depth = x.depth + 1;
                  via = e.sink;
                }) (step names x.key);
          })
        )
      );
in
{
  inherit
    impact
    ;
}
