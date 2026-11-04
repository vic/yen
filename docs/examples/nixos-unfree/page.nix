{
  title = "Unfree packages from many files";
  description = "Each feature names its unfree packages. One allowUnfreePredicate per host reads them all.";
  section = "nixos";
  route = "nixos/unfree";
  order = 3;

  body =
    { docs, result, ... }:
    [
      ''
        `nixpkgs.config.allowUnfree = true` allows every unfree package. To allow only some, nixpkgs has
        `allowUnfreePredicate`. It is a function, so the module system cannot merge it: when two modules set it, they
        conflict ([nixpkgs#55674](https://github.com/NixOS/nixpkgs/issues/55674),
        [discourse](https://discourse.nixos.org/t/appending-entries-to-nixpkgs-config-allowunfreepredicate/55844)).
        The usual fix declares a list option and sets the predicate once from it. Den ships the same fix as
        `den.batteries.unfree`, its most used battery ([Every Den battery](/den/batteries/)).

        In yen the list option is a [sink](/behavior/sinks/). This file declares it on the host kind:
      ''
      (docs.fileNoted "" "modules/unfree.nix")
      ''
        `(1)` is the sink. `(2)` is its `nixos` key: one predicate that reads every name the sink collected. `(3)` is
        its `out` key: the list of each host becomes a flake output, so you can see it.

        A feature gives the names that it needs, next to the packages. A user can give names too: they go up to each
        host of the user.
      ''
      (docs.fileNoted "" "modules/features.nix")
      ''
        `(1)` gives the names of the `gaming` [aspect](/behavior/aspects/). `(2)` gives the names from a user. The
        `server` host has no names, so its sink gives nothing: nixpkgs refuses every unfree package there, as by
        default. The flake output shows the list of each host:
      ''
      (docs.value result.flake.unfree)
      (docs.tabs [
        {
          label = "fleet.nix";
          body = docs.file "modules/fleet.nix";
        }
      ])
      (docs.note "Home-manager" ''
        With `home-manager.useGlobalPkgs = true`, home-manager uses the host's `pkgs`, so the host predicate applies to
        home packages too. For a standalone home, give the home kind the same sink with a `homeManager` key.
      '')
      (docs.tip "As a battery" ''
        This page writes the rule by hand. It is ready as `yen.lib.batteries.nixos.unfree` (and `insecure`):
        see [NixOS batteries](/batteries/nixos/). When it does not fit, keep your own copy of the lines above.
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
      per-host = eq (result.flake.unfree) ({
        desk = [
          "steam"
          "steam-unwrapped"
          "vscode"
        ];
      });
    };

  e2e =
    {
      flake,
      eq,
      yes,
      no,
      ...
    }:
    let
      ok = h: p: (builtins.tryEval flake.nixosConfigurations.${h}.pkgs.${p}.drvPath).success;
    in
    {
      steam = yes (ok "desk" "steam-unwrapped");
      vscode = yes (ok "desk" "vscode");
      others-denied = no ((ok "desk" "zoom-us"));
      server-denied = no ((ok "server" "vscode"));
    };
}
