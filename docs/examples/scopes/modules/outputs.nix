# The flake gives the scope ids. An aspect asks the tree for the whole fleet (`graph = true`) to read them.
{ yen, ... }:
let
  whole.graph = true; # (1) a tree request: the whole fleet
  fleetOf = tree: builtins.head (tree.select whole); # the whole fleet, with its data
in
{
  yen.kinds.fleet.sinks.out.reduce = yen.lib.reduce.merge;
  yen.flake = { out, ... }: out;
  yen.aspects.tree = {
    at = yen.kinds.fleet;
    cycle =
      { tree, ... }:
      {
        tree = [ whole ];
        out = [
          {
            scopes = map (s: s.id) (fleetOf tree).lib.graph.scopes; # (2)
          }
        ];
      };
  };
}
