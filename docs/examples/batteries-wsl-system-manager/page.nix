{
  title = "WSL and system-manager";
  description = "One fleet for NixOS, NixOS on WSL, and other Linux distributions with system-manager: shared aspects, one output per kind.";
  section = "batteries";
  route = "batteries/wsl-system-manager";
  order = 11;

  body =
    { docs, result, ... }:
    [
      ''
        One fleet can mix machines running NixOS, machines running NixOS inside WSL on Windows, and machines on another
        Linux distribution configured by [system-manager](https://github.com/numtide/system-manager). Each is a
        [kind](/model/kinds-fields/) with its own [sink](/behavior/sinks/), and each sink builds its own flake output. An
        [aspect](/behavior/aspects/) at several kinds shares one piece of configuration between them.

        The kinds, their sinks and the [batteries](/batteries/) that build them:
      ''
      (docs.fileNoted "" "modules/fleet.nix")
      ''
        - `(1)` builds `nixosConfigurations.<name>` for a NixOS host.
        - `(2)` is the same battery for a machine on WSL. WSL needs no battery of its own, since it's NixOS with one more module.
        - `(3)` is that module, [NixOS-WSL](https://github.com/nix-community/NixOS-WSL). The `wsl` aspect adds it, together with `wsl.enable`, at the `wsl` kind.
        - `(4)` builds `systemConfigs.<name>` for the other Linux, with `system-manager.lib.makeSystemConfig`.

        The machines, and the `tools` aspect, which gives the same packages to all three through each kind's key:
      ''
      (docs.fileNoted "" "modules/machines.nix")
      ''
        At `(1)`, the packages go to NixOS and WSL through the `nixos` key, and at `(2)`, to the other Linux through the
        `system` key. The flake outputs, including the [Lean check](/query/lean/) every flake gets:
      ''
      (docs.value (builtins.mapAttrs (_: builtins.attrNames) result.flake))
      ''
        | Machine | Kind | Sink | Battery | Output |
        |---|---|---|---|---|
        | NixOS | `host` | `nixos` | `nixos.system` | `nixosConfigurations.<name>` |
        | NixOS on WSL | `wsl` | `nixos` | `nixos.system`, plus the NixOS-WSL module | `nixosConfigurations.<name>` |
        | Other Linux | `machine` | `system` | `configurations` with `system-manager.lib.makeSystemConfig` | `systemConfigs.<name>` |

        nix-darwin works the same way, with a kind that has a `darwin` sink and the `darwin.system` battery (see
        [Platform batteries](/batteries/platforms/)). An aspect at `host`, `wsl`, `machine` and the darwin kind shares
        its configuration with all four.
      ''
    ];

  checks =
    { result, eq, ... }:
    {
      # `checks`: the Lean check every flake gets (checks.<system>.yen-lean)
      outputs = eq (builtins.mapAttrs (_: builtins.attrNames) result.flake) {
        checks = [
          "aarch64-darwin"
          "aarch64-linux"
          "x86_64-linux"
        ];
        nixosConfigurations = [
          "desk"
          "laptop"
        ];
        systemConfigs = [ "vps" ];
      };
      errors = eq result.errors [ ];
    };

  # real evaluations: the WSL host has the NixOS-WSL module on, and system-manager builds a configuration
  e2e =
    { flake, eq, ... }:
    {
      wsl = eq flake.nixosConfigurations.laptop.config.wsl.enable true;
      not-wsl = eq (flake.nixosConfigurations.desk.config ? wsl) false;
      shared = eq (builtins.elem "git" (
        map (p: p.pname or "") flake.nixosConfigurations.laptop.config.environment.systemPackages
      )) true;
      system-manager = eq (builtins.isString flake.systemConfigs.vps.drvPath) true;
    };
}
