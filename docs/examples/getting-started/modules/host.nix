# A host has a system. Its `nixos` sink collects NixOS modules and builds the host.
{
  yen,
  lib,
  inputs,
  ...
}:
{
  yen.kinds.host = {
    fields.system = yen.types.string; # (1)
    sinks.nixos.out =
      { host, nixos, ... }: # (2)
      {
        nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem {
          inherit (host) system;
          modules = nixos; # (3)
        };
      };
  };

  yen.host.laptop.system = "x86_64-linux";
}
