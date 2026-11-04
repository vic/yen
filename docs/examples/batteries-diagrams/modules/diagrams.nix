# Diagrams of the fleet: every view is data ({ nodes; edges; }), flowchart renders it.
{ yen, ... }:
let
  whole.graph = true; # a tree request: the whole fleet
  inherit (yen.lib.batteries) mermaid;
  draw = direction: view: mermaid.flowchart { inherit direction; } view;
  # the diagrams of a fleet: `fleet` is the whole fleet, with its data, that the tree request selects
  diagramsOf = fleet: {
    # each environment as a subgraph around its hosts
    scopes = draw "TD" (
      mermaid.scopes {
        keep = s: !(fleet.lib.holds fleet.kinds.fleet s);
        label = s: s.name;
        group = s: if fleet.lib.holds fleet.kinds.host s then dirOf s.id else null; # (1) hosts inside their environment (the parent id)
      } fleet.lib.graph
    );
    kinds = draw "LR" (mermaid.kinds fleet.kinds); # (2)
    gates = draw "LR" (mermaid.gates fleet.aspects); # (3)
    routes = draw "BT" (mermaid.routes fleet.lib.graph); # (4)
    # (5) kind level: kind -> sink -> kind, counted; sinks as rounded nodes, outputs as cylinders
    routing = mermaid.flowchart {
      shapes = {
        sink = mermaid.shapes.round;
      };
    } (mermaid.routing fleet.lib.graph);
    sinks = mermaid.flowchart {
      shapes = {
        sink = mermaid.shapes.round;
        output = mermaid.shapes.cylinder;
      };
    } (mermaid.sinks fleet.lib);
  };
in
{
  yen.aspects.diagrams = {
    at = yen.fleet.main;
    cycle =
      { tree, ... }:
      {
        tree = [ whole ]; # (6)
        out = [ { diagrams = diagramsOf (builtins.head (tree.select whole)); } ];
      };
  };
}
