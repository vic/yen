# A guest lives under its host. Its own `nixos` sink forwards up, into the host's containers.
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
    spawns.guest = yen.lib.pointing "on" yen.guest; # (1)
    sinks.nixos.out =
      { host, nixos, ... }:
      {
        nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem { modules = nixos; };
      };
  };
  yen.kinds.guest = {
    fields.on = yen.kinds.host; # (2)
    sinks.nixos.nixos = # (3)
      { guest, nixos, ... }:
      {
        containers.${guest.name} = {
          autoStart = true;
          config.imports = nixos; # (4)
        };
      };
  };

  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
}
