{
  title = "From a flake";
  description = "Move a flake with a mkHost helper, shared modules and home-manager to yen. Same systems, no helper.";
  section = "migrate";
  order = 2;

  body =
    { docs, ... }:
    [
      ''
        Most flakes grow the same shape: a `mkHost` helper, a `common.nix`, one file per host, and home-manager
        as a NixOS module. This page moves that shape to yen. The docs check that each host gives the same toplevel
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

        `mkHost` knew how to build a host. In yen, a [kind](/model/kinds-fields/) knows it:
      ''
      (docs.fileNoted "{14-18,22-26}" "modules/fleet.nix")
      ''
        At `(1)`, the `nixos` [sink](/behavior/sinks/) of the `host` kind builds the system. At `(2)`, the
        `homeManager` sink of the `user` kind forwards to `nixos` on each host the user lives under
        ([forwards](/behavior/forwards/)).

        ## Shared modules become aspects

        `common.nix` was in every host's list. As an [aspect](/behavior/aspects/) it is active at every host. home-manager is active only
        where a user lives:
      ''
      (docs.fileNoted "{5,17}" "modules/features/common.nix")
      ''
        `(1)` makes `common` active at every host. `(2)` makes `home-manager` active at every scope below a user, so
        only hosts with users get it.

        ## Host files hold data and hardware

        A host file declares the instance and the parts only that host has. Features that only one host uses are
        aspects with that host in `at`, as `nginx` is at `(1)` in `features/roles.nix`:
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

        `home-manager.users.alice` was written in the flake for every host. Now alice is data: she says which hosts
        she uses, and her aspect gives her account and her home:
      ''
      (docs.fileNoted "" "modules/alice.nix")
      ''
        `(1)` makes the aspect active at alice. `(2)` is her `nixos` module: yen fills `user` with her. `(3)` is her
        home, which goes to the `homeManager` sink of each host she lives under.
      ''
      (docs.note "Adding a host" ''
        Before: add a line to the flake, and maybe a parameter to `mkHost`. After: add `yen.host.<name>` in its own file,
        and add it to the `hosts` of its users. Nothing else changes.
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
