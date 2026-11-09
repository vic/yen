{
  title = "nix-darwin machines";
  description = "NixOS hosts and macs in one fleet. Aspects write `os` once and each platform forwards it.";
  section = "recipes";
  order = 5;

  body =
    { docs, result, ... }:
    [
      ''
        Many options mean the same thing on NixOS and nix-darwin, like `networking.hostName`,
        `environment.systemPackages` and `nix.settings`, so you want to write them once. The kinds `host` and `mac` each
        have an `os` [sink](/behavior/sinks/), and each one [forwards](/behavior/forwards/) to its platform's sink:
      ''
      (docs.fileNoted "{12-13,24-25}" "modules/platforms.nix")
      ''
        At `(1)`, a `host` forwards its `os` sink to `nixos`, and at `(2)`, the `nixos` sink gives `nixosConfigurations`.
        At `(3)`, a `mac` forwards its `os` sink to `darwin`, and at `(4)`, the `darwin` sink gives `darwinConfigurations`.

        This [aspect](/behavior/aspects/) writes `os` once:
      ''
      (docs.fileNoted "" "modules/shared.nix")
      ''
        At `(1)`, it is active at both kinds, and at `(2)`, `os` holds the options NixOS and nix-darwin share.
        The two machines:
      ''
      (docs.fileNoted "" "modules/machines.nix")
      ''
        `(1)` is a NixOS machine and `(2)` is a mac, and each has its own aspect with its platform's options. In the routes,
        `shared` gives `os` at each machine, and each `os` sink feeds its platform's sink:
      ''
      (docs.routes result)
      (docs.sh ''
        sudo nixos-rebuild switch --flake .#server
        sudo darwin-rebuild switch --flake .#studio
      '')
      (docs.note "Platform-only content" ''
        Keep platform-only options under their own key: `nixos` for NixOS, `darwin` for nix-darwin. An aspect active at
        both kinds can give `os`, `nixos` and `darwin` at the same time, and each element goes to its own sink.
      '')
    ];

  checks =
    {
      result,
      eq,
      yes,
      no,
      ...
    }:
    {
      forwards = {
        t1 = yes (builtins.any (e: e.sink == "darwin" && e.origin == "sink os") result.graph.edges);
        t2 = yes (builtins.any (e: e.sink == "nixos" && e.origin == "sink os") result.graph.edges);
      };
    };
  e2e =
    {
      flake,
      eq,
      yes,
      no,
      ...
    }:
    {
      mac = eq (flake.darwinConfigurations.studio.config.networking.hostName) ("studio");
      mac-git = yes (
        builtins.any (
          p: (p.pname or "") == "git"
        ) flake.darwinConfigurations.studio.config.environment.systemPackages
      );
      host = eq (flake.nixosConfigurations.server.config.networking.hostName) ("server");
    };
}
