# A host asks the tree for every host, and counts the other ones.
{ yen, ... }:
{
  yen.aspects.peers = {
    at = yen.kinds.host;
    cycle = # (1)
      { tree, scope, ... }:
      let
        hosts.instances = yen.kinds.host; # (2)
      in
      {
        tree = [ hosts ]; # (3)
        out = [
          {
            peers.${scope.name} = builtins.length (
              builtins.filter (h: h.name != scope.name) (tree.select hosts) # (4)
            );
          }
        ];
      };
  };
}
