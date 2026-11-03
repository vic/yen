# Three kinds of machine: a NixOS host, a NixOS host that runs in WSL, and a machine of another Linux distribution
# that system-manager configures. Each kind has its own sink and builds its own flake output.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  inherit (yen.lib.batteries) configurations nixos;
in
{
  yen.kinds.fleet = {
    spawns = {
      host = _: yen.host;
      wsl = _: yen.wsl;
      machine = _: yen.machine;
    };
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.fleet.main = { };

  yen.kinds.host.sinks.nixos.out = nixos.system {
    from = yen.kinds.host.sinks.nixos;
    inherit (inputs) nixpkgs;
  };
  # WSL is NixOS with the NixOS-WSL module: the same battery, one more module
  yen.kinds.wsl.sinks.nixos.out = nixos.system {
    from = yen.kinds.wsl.sinks.nixos;
    inherit (inputs) nixpkgs;
  };
  yen.aspects.wsl = {
    at = yen.kinds.wsl;
    nixos = {
      imports = [ inputs.nixos-wsl.nixosModules.default ];
      wsl.enable = true;
    };
  };
  # system-manager: `systemConfigs.<name>` from the modules of the machine's sink
  yen.kinds.machine.sinks.system.out = configurations {
    from = yen.kinds.machine.sinks.system;
    output = "systemConfigs";
    build = _: modules: inputs.system-manager.lib.makeSystemConfig { inherit modules; };
  };

  yen.flake = { out, ... }: out;
}
