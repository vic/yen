{
  title = "Shared pkgs";
  description = "Import nixpkgs once per system, not once per host. Same systems, about a third less evaluation.";
  section = "perf";
  order = 1;

  body =
    { docs, ... }:
    [
      ''
        Yen's own share of a host's evaluation is small, 1.4% on the reference fleet's `lb`. Most of the time goes to
        nixpkgs `pkgs` (56%) and the NixOS module system (36%), and by default every host imports nixpkgs all over again.

        Instead, a host can reuse the `pkgs` of the first sharing host on its system, the leader. This file declares the
        rule, and the [reference fleet](https://github.com/vic/yen/tree/main/reference) has the full version.
      ''
      (docs.fileNoted "{11,20-25,44,50,58}" "modules/fleet.nix")
      ''
        `(1)` finds the leader, the first sharing host with the same `system`. `(2)` makes a follower's modules using
        nixpkgs' `readOnlyPkgs` module, so the follower reuses the leader's built `pkgs`. `(3)` is the field a host sets
        to share, `sharedPkgs = true`. `(4)` is the `out` [arg](/behavior/args/), which lazily gives the leader's built
        `pkgs`. At `(5)` a follower adds those modules to its own.

        These hosts share their `pkgs`:
      ''
      (docs.file "modules/hosts.nix")
      ''
        ## The check

        A follower must build exactly what it would build alone. `ownPkgs` is each host built with its own `pkgs`, and
        the docs check that every host's toplevel `drvPath` is the same both ways.
      ''
      (docs.table
        [ "Reference fleet: lb, web-1, web-2 toplevel" "CPU" "Thunks" "GC total" ]
        [
          [
            "each its own pkgs"
            "35.3 s"
            "36.6 M"
            "2.71 GB"
          ]
          [
            "shared pkgs"
            "24.8 s"
            "29.3 M"
            "1.96 GB"
          ]
        ]
      )
      ''
        Measured on the reference fleet, with the same `drvPath`s both ways
        ([README](https://github.com/vic/yen/tree/main/reference#shared-pkgs-one-nixpkgs-per-channel-and-system)).
      ''
      (docs.caution "Two rules" ''
        - A sharing host can't set its own `nixpkgs.config` or `nixpkgs.overlays`, because the group shares them.
          Give the same ones to every host in the group, or leave the host out of the group.
        - Keep documentation off on sharing hosts, since the manual and man pages differ when `pkgs` is shared.
      '')
    ];

  # fast: the group and its leader, with no NixOS eval (the e2e checks below build the systems)
  checks =
    { result, eq, ... }:
    {
      leader = eq result.flake.sharedLeader {
        app-1 = null;
        app-2 = "app-1";
        app-3 = "app-1";
      };
    };

  e2e =
    { flake, eq, ... }:
    let
      t = c: c.config.system.build.toplevel.drvPath;
    in
    builtins.listToAttrs (
      map
        (h: {
          name = "same-${h}";
          value = eq (t flake.nixosConfigurations.${h}) (t flake.ownPkgs.${h});
        })
        [
          "app-1"
          "app-2"
          "app-3"
        ]
    );
}
