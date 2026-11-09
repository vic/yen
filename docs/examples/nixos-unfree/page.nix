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
        `nixpkgs.config.allowUnfree = true` allows every unfree package. To allow only some of them, nixpkgs has
        `allowUnfreePredicate`. But it's a function, so the module system can't merge it, and two modules that set it
        conflict ([nixpkgs#55674](https://github.com/NixOS/nixpkgs/issues/55674),
        [discourse](https://discourse.nixos.org/t/appending-entries-to-nixpkgs-config-allowunfreepredicate/55844)).
        The usual fix declares a list option and sets the predicate once from it. Den ships the same fix as
        `den.batteries.unfree`, its most used battery ([Every Den battery](/den/batteries/)).

        In Yen that list option is a [sink](/behavior/sinks/). This file declares it on the host kind:
      ''
      (docs.fileNoted "" "modules/unfree.nix")
      ''
        `(1)` is the sink. `(2)` is its `nixos` key, a single predicate that reads every name the sink collected. `(3)` is
        its `out` key, which turns each host's list into a flake output so you can see it.

        A feature gives the names it needs right next to its packages. A user can give names too, and they go up to each
        of the user's hosts.
      ''
      (docs.fileNoted "" "modules/features.nix")
      ''
        `(1)` gives the names for the `gaming` [aspect](/behavior/aspects/), and `(2)` gives names from a user. The
        `server` host has no names, so its sink gives nothing, and nixpkgs refuses every unfree package there, just like
        the default. The flake output shows each host's list:
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
        This page writes the rule by hand, but it's ready-made as `yen.lib.batteries.nixos.unfree` (and `insecure`),
        see [NixOS batteries](/batteries/nixos/). When it doesn't fit, keep your own copy of the lines above.
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
