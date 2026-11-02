# The fleet is the root. Its `out` sink is the flake. A host builds NixOS from its `nixos` sink.
{ yen, inputs, ... }:
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.host.sinks.nixos.out =
    { host, nixos, ... }:
    {
      nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem { modules = nixos; };
    };

  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
}
