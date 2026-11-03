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
    let
      sc = scopeIn "impact" t;
      id = sc.ok.id;
      # a sink by reference: yen.kinds.<kind>.sinks.<sink>, or { sink; } from outside the fleet
      names =
        if sinks == null then
          null
        else
          map (k: if isAttrs k then k.__sink or k.sink or null else null) sinks;
      bad = if sinks == null then [ ] else filter (k: !isString k || !elem k sinkNames) names;
      step = from: filter (e: e.from == from && (sinks == null || elem e.sink names)) graph.edges;
      reached = genericClosure {
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
            }) (step x.key);
      };
      c = cut max (
        map
          (x: {
            scope = pathOf byId.${x.key};
            inherit (x) depth;
            via.sink = x.via;
          })
          (
            b.sort (p: q: p.depth < q.depth || p.depth == q.depth && p.key < q.key) (
              filter (x: x.key != id) reached
            )
          )
      );
    in
    if !(sc ? ok) then
      sc
    else if bad != [ ] then
      unknown "impact" (if isString (head bad) then head bad else "") sinkNames { code = "unknown-sink"; }
      // {
        near = map (k: { sink = k; }) (near (if isString (head bad) then head bad else "") sinkNames);
      }
    else
      {
        reached = c.items;
        inherit (c) truncated;
        inherit hops;
      };
in
{
  inherit
    impact
    ;
}
