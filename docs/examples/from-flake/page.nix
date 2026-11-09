{
  title = "From a flake";
  description = "Move a flake with a mkHost helper, shared modules and home-manager to Yen: the same systems, with no helper.";
  section = "migrate";
  order = 2;

  body =
    { docs, ... }:
    [
      ''
        Most flakes grow the same shape: a `mkHost` helper, a `common.nix`, one file per host, and home-manager
        as a NixOS module. This page moves that shape to Yen, and the docs check that each host gives the same toplevel
        `drvPath` before and after.
      ''
      (docs.tabs [
        {
          label = "flake.nix";
          body = docs.file "before/flake.nix";
        }
        {
          label = "common.nix";
          body = docs.file "before/common.nix";
        }
        {
          label = "hosts/web.nix";
          body = docs.file "before/hosts/web.nix";
        }
        {
          label = "hosts/desk.nix";
          body = docs.file "before/hosts/desk.nix";
        }
        {
          label = "home.nix";
          body = docs.file "before/home.nix";
        }
      ])
      ''
        ## The helper becomes a kind

        `mkHost` knew how to build a host. In Yen, a [kind](/model/kinds-fields/) knows it:
      ''
      (docs.fileNoted "{14-18,22-26}" "modules/fleet.nix")
      ''
        At `(1)` the `host` kind's `nixos` [sink](/behavior/sinks/) builds the system, and at `(2)` the `user` kind's
        `homeManager` sink forwards to `nixos` on each host the user lives under
        ([forwards](/behavior/forwards/)).

        ## Shared modules become aspects

        `common.nix` was in every host's list. As an [aspect](/behavior/aspects/) it's active at every host, while
        home-manager is active only where a user lives:
      ''
      (docs.fileNoted "{5,17}" "modules/features/common.nix")
      ''
        `(1)` makes `common` active at every host. `(2)` makes `home-manager` active at every scope below a user, so
        only hosts with users get it.

        ## Host files hold data and hardware

        A host file declares the instance plus the parts only that host has. A feature only one host uses is an
        aspect with that host in `at`, like `nginx` at `(1)` in `features/roles.nix`:
      ''
      (docs.tabs [
        {
          label = "hosts/web.nix";
          body = docs.file "modules/hosts/web.nix";
        }
        {
          label = "hosts/desk.nix";
          body = docs.file "modules/hosts/desk.nix";
        }
        {
          label = "features/roles.nix";
          body = docs.fileNoted "" "modules/features/roles.nix";
        }
      ])
      ''
        ## People own their homes

        The flake used to write `home-manager.users.alice` for every host. Now alice is data that says which hosts
        alice uses, and alice's aspect gives the account and the home:
      ''
      (docs.fileNoted "" "modules/alice.nix")
      ''
        `(1)` makes the aspect active at alice. `(2)` is alice's `nixos` module, where Yen fills `user` with alice.
        `(3)` is the home, which goes to the `homeManager` sink of each host alice lives under.
      ''
      (docs.note "Adding a host" ''
        Before, you added a line to the flake, and maybe a parameter to `mkHost`. Now you add `yen.host.<name>` in its own
        file and add it to its users' `hosts`. Nothing else changes.
      '')
      (docs.links [
        {
          title = "Users and homes";
          href = "/recipes/users-homes/";
          description = "home-manager in NixOS, on macs, and standalone.";
        }
        {
          title = "Environments";
          href = "/recipes/environments/";
          description = "prod, staging, lab: hosts grouped by where they run.";
        }
      ])
    ];

  e2e =
    {
      inputs,
      dir,
      flake,
      eq,
      yes,
      no,
      ...
    }:
    let
      before = ((import (dir + "/before/flake.nix")).outputs inputs).nixosConfigurations;
      t = c: c.config.system.build.toplevel.drvPath;
    in
    {
      same-web = eq (t before.web) (t flake.nixosConfigurations.web);
      same-desk = eq (t before.desk) (t flake.nixosConfigurations.desk);
    };
}
