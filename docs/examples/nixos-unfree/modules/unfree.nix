# allowUnfreePredicate is a function: two modules that set it conflict. A sink collects names; one predicate reads them.
{ lib, ... }:
{
  yen.kinds.host.sinks.unfree = {
    # (1)
    nixos = # (2)
      { unfree, ... }:
      {
        nixpkgs.config.allowUnfreePredicate = pkg: lib.elem (lib.getName pkg) (lib.flatten unfree);
      };
    # the list per host, as a flake output: review it before a deploy
    out = # (3)
      { host, unfree, ... }:
      {
        unfree.${host.name} = lib.sort lib.lessThan (lib.flatten unfree);
      };
  };
}
