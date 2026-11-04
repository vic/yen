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
        A fleet can mix machines that run NixOS, machines that run NixOS inside WSL on Windows, and machines of another
        Linux distribution that [system-manager](https://github.com/numtide/system-manager) configures. Each is a
        [kind](/model/kinds-fields/) with its own [sink](/behavior/sinks/), and each sink builds its own flake output.
        An [aspect](/behavior/aspects/) at several kinds shares one piece of configuration between them.

        The kinds, their sinks and the [batteries](/batteries/) that build them:
      ''
      (docs.fileNoted "" "modules/fleet.nix")
      ''
        - `(1)` builds `nixosConfigurations.<name>` for a NixOS host.
        - `(2)` is the same battery for a machine on WSL. WSL needs no battery of its own: it is NixOS with one more module.
        - `(3)` is that module, [NixOS-WSL](https://github.com/nix-community/NixOS-WSL). The aspect `wsl` adds it, and `wsl.enable`, at the kind `wsl`.
        - `(4)` builds `systemConfigs.<name>` for another Linux, with `system-manager.lib.makeSystemConfig`.

        The machines, and the aspect `tools`, which gives the same packages to all three through the key of each kind:
      ''
      (docs.fileNoted "" "modules/machines.nix")
      ''
        At `(1)`, the packages go to NixOS and WSL through the `nixos` key. At `(2)`, they go to the other Linux through the `system` key.
        The flake outputs, with the [Lean check](/query/lean/) every flake gets:
      ''
      (docs.value (builtins.mapAttrs (_: builtins.attrNames) result.flake))
      ''
        | Machine | Kind | Sink | Battery | Output |
        |---|---|---|---|---|
        | NixOS | `host` | `nixos` | `nixos.system` | `nixosConfigurations.<name>` |
        | NixOS on WSL | `wsl` | `nixos` | `nixos.system`, plus the NixOS-WSL module | `nixosConfigurations.<name>` |
        | Other Linux | `machine` | `system` | `configurations` with `system-manager.lib.makeSystemConfig` | `systemConfigs.<name>` |

        nix-darwin works the same way: a kind with a `darwin` sink and the battery `darwin.system` (see
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
