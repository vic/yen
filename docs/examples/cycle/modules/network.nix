# A cycle: it reads sources (the tree, the sinks) and writes sinks. It gives 0 to n elements.
{ yen, ... }:
{
  yen.aspects.vm-network = {
    at = yen.lib.below yen.kinds.guest; # every host with a guest
    cycle = # (1)
      { tree, ... }:
      let
        vms.children = yen.kinds.guest; # (2) a request: the guest children
      in
      {
        tree = [ vms ]; # (3)
        bridges = map (g: "br-${g.name}") (builtins.head (tree.select vms)); # (4) one element per guest
        errors = [ ];
      };
  };
}
