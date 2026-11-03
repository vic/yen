# An eval part: the agent surface: JSON-safe answers, every list says when it was cut
# A part is `_: st:`; `st` is the state of one eval: the names of every part, `root`, and the base helpers.
_: st:
let
  inherit (st)
    active
    aspectNames
    b
    below
    check
    edgeOut
    errorsAll
    filter
    graph
    kindNames
    length
    pathOf
    schema
    scopeIn
    scopes
    static
    undefined
    ;
  # ── the agent surface: JSON-safe answers, every list says when it was cut ──
  cut = max: xs: cutTo xs (if length xs < max then length xs else max);
  cutTo = xs: shown: {
    items = b.genList (b.elemAt xs) shown;
    truncated = {
      inherit shown;
      of = length xs;
    };
  };
  #: result.context :: scope -> { maxEdges ? ; maxAspects ? ; } -> { scope; kind; name; parent; children; aspects; undefined; given; received; errors; } -- one scope for an agent, cut to size; refs in, identities out
  context =
    t:
    {
      maxEdges ? 20,
      maxAspects ? 50,
    }:
    contextAt (scopeIn "context" t) maxEdges maxAspects;
  contextAt =
    sc: maxEdges: maxAspects:
    if !(sc ? ok) then sc else contextOf maxEdges maxAspects sc.ok;
  edgesCut = max: es: cut max (map edgeOut es);
  contextOf =
    maxEdges: maxAspects: s:
    static.jsonSafe {
      scope = pathOf s;
      inherit (s) kind name;
      parent = if s.parent == null then null else pathOf s.parent;
      children = map pathOf (below s);
      aspects = cut maxAspects (map (n: { aspect = n; }) (filter (n: active.${n}.${s.id}) aspectNames));
      undefined = map (x: { inherit (x) aspect; }) (filter (x: x.scope == s.id) undefined);
      given = edgesCut maxEdges (filter (e: e.from == s.id) graph.edges);
      received = edgesCut maxEdges (filter (e: e.to == s.id) graph.edges);
      errors = filter (e: e.from == s.id) errorsAll;
    };
  #: result.agent :: { schema; undefined; errors; check; counts; } -- the fleet summary an agent reads first
  agent = static.jsonSafe {
    inherit schema undefined;
    errors = errorsAll;
    check = { inherit (check) violations incomplete ok; };
    counts = {
      scopes = length scopes;
      edges = length graph.edges;
      aspects = length aspectNames;
      kinds = length kindNames;
    };
  };
in
{
  inherit
    cut
    context
    agent
    ;
}
