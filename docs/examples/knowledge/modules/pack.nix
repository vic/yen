# The routing graph as a knowledge pack: sorted N-Triples with a sha256. Same fleet, same hash, any file order.
{ yen, ... }:
let
  whole.graph = true; # (1) a tree request: the whole fleet
  fleetOf = tree: builtins.head (tree.select whole); # the whole fleet, with its data
in
{
  yen.aspects.pack = {
    # (2)
    at = yen.kinds.fleet;
    cycle =
      { tree, ... }:
      {
        tree = [ whole ];
        out = [
          {
            rdfPack = removeAttrs (yen.lib.rdf.share {
              # (3)
              graph = (fleetOf tree).lib.graph;
              active = { };
              errors = [ ];
            }) [ "ntriples" ];
          }
        ];
      };
  };
}
