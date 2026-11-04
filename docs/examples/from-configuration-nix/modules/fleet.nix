# The fleet spawns hosts and the users that log in to them.
{
  yen,
  inputs,
  ...
}:
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.host = {
    spawns.user = yen.lib.pointing "hosts" yen.user; # (1)
    sinks.nixos.out = # (2)
      { host, nixos, ... }:
      {
        nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem { modules = nixos; };
      };
  };
  yen.kinds.user.fields = {
    hosts = yen.lib.listOf yen.kinds.host;
    groups = yen.lib.opt (yen.lib.listOf yen.lib.str) [ ]; # (3)
  };

  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
}
