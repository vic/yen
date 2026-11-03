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
  cut =
    max: xs:
    let
      shown = if length xs < max then length xs else max;
    in
    {
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
    let
      sc = scopeIn "context" t;
      s = sc.ok;
      id = s.id;
      edges = es: cut maxEdges (map edgeOut es);
    in
    if !(sc ? ok) then
      sc
    else
      static.jsonSafe {
        scope = pathOf s;
        inherit (s) kind name;
        parent = if s.parent == null then null else pathOf s.parent;
        children = map pathOf (below s);
        aspects = cut maxAspects (map (n: { aspect = n; }) (filter (n: active.${n}.${id}) aspectNames));
        undefined = map (x: { inherit (x) aspect; }) (filter (x: x.scope == id) undefined);
        given = edges (filter (e: e.from == id) graph.edges);
        received = edges (filter (e: e.to == id) graph.edges);
        errors = filter (e: e.from == id) errorsAll;
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
