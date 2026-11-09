{
  title = "Every Den battery";
  description = "Each den.batteries.* entry, in Yen: an aspect, a field, a sink, or nothing at all.";
  section = "den";
  route = "den/batteries";
  order = 3;

  body =
    { docs, ... }:
    [
      ''
        A Den battery is an [aspect](/behavior/aspects/) that Den ships. You include it, sometimes with an argument, like
        `(den.batteries.user-shell "fish")`. In Yen there's nothing to ship: the argument becomes a typed field of
        the host or the user, and the battery is a short aspect whose `at` says where it applies.

        The table lists every battery in Den's `modules/aspects/batteries/`. The count is how often each one shows up in
        the 20 most starred public Den configurations on GitHub (October 2026).
      ''
      (docs.table
        [ "Den battery" "Uses" "Yen" ]
        [
          [
            "`unfree [ … ]`"
            "41"
            "`nixos.unfree`, or by hand: [Unfree packages from many files](/nixos/unfree/)"
          ]
          [
            "`primary-user`"
            "30"
            "`nixos.primary-user`, or by hand: [From Den](/migrate/from-den/#batteries-are-aspects)"
          ]
          [
            "`define-user`"
            "27"
            "`nixos.define-user`, or by hand: [From Den](/migrate/from-den/#batteries-are-aspects)"
          ]
          [
            "`hostname`"
            "25"
            "`nixos.hostname`, or by hand below"
          ]
          [
            "`forward`"
            "16"
            "a [sink](/behavior/sinks/) whose key gives to another sink: [Custom classes](/den/classes/)"
          ]
          [
            "`user-shell \"fish\"`"
            "11"
            "a `shell` field and one aspect, below"
          ]
          [
            "`inputs'`, `self'`"
            "21"
            "`inputs` is an arg of every Yen [module](/principles/modules/); per system: `inputs.x.packages.\${pkgs.stdenv.hostPlatform.system}`"
          ]
          [
            "`flake-scope`"
            "–"
            "nothing: `yen`, `lib` and `inputs` are args of every Yen module"
          ]
          [
            "`host-aspects`"
            "9"
            "an aspect at the users `within` the host that opt in: [includes and provides](/den/includes/)"
          ]
          [
            "`mutual-provider`"
            "6"
            "nothing: in Den it's inert; in Yen `within` routes both ways"
          ]
          [
            "`tty-autologin \"ana\"`, `vm-autologin`"
            "7"
            "a host field that names a user, below"
          ]
          [
            "`insecure [ … ]`"
            "5"
            "`nixos.insecure`, or by hand below: `nixpkgs.config` doesn't merge lists"
          ]
          [
            "`import-tree ./dir`"
            "2"
            "the Yen template already loads `modules/` with import-tree; plain NixOS files go in a `nixos.imports`"
          ]
          [
            "`os` class (os-class)"
            "–"
            "an `os` sink that forwards to `nixos` and `darwin`: [nix-darwin machines](/recipes/darwin/)"
          ]
          [
            "`user` class (os-user)"
            "–"
            "an `account` sink on the user, below"
          ]
          [
            "`home-manager`"
            "–"
            "an aspect where a host has users: [From Den](/migrate/from-den/)"
          ]
          [
            "`hjem`, `maid`"
            "–"
            "a user sink, chosen by a `classes` field: ${
              docs.fleet "modules/den/custom-classes.nix" null "den/custom-classes.nix"
            }"
          ]
          [
            "`wsl`"
            "–"
            "a host field `wsl` and an aspect whose `at` reads it, as in [Many hosts, one base](/nixos/hosts/)"
          ]
        ]
      )
      ''
        ## Parameters are fields

        `user-shell "fish"` and `tty-autologin "ana"` take an argument. In Yen the argument is a typed
        [field](/model/kinds-fields/) on the instance. This file declares the Den schema with both fields.
      ''
      (docs.fileNoted "" "modules/fleet.nix")
      ''
        `(1)` is a host's `autologin` field. Its type is a user or nothing, so `autologin` must be a user
        that exists. `(2)` is a user's `shell` field, whose type is one of three names, with `bash` as the default.
        A typo like `shell = "fsh"` is an error at `yen.user.ana.shell`.

        Each battery below is an [aspect](/behavior/aspects/). Its `at` says where it applies, and its `nixos` key
        gives a NixOS module to the [sink](/behavior/sinks/) with that name.
      ''
      (docs.file "modules/batteries.nix")
      ''
        ## Insecure packages need a sink too

        `permittedInsecurePackages` is a list, but it lives in `nixpkgs.config`, and `nixpkgs.config` doesn't merge lists.
        When two NixOS modules set it, only one list survives, with no error. We first wrote this page without the
        sink, on NixOS 25.05, and bob's entry was lost. The fix is the same as for `unfree`
        ([Unfree packages from many files](/nixos/unfree/)): a sink of names, and one module that sets the option.
      ''
      (docs.file "modules/insecure.nix")
      (docs.tip "As a battery" ''
        This page writes each battery by hand. `hostname`, `define-user`, `primary-user`, `unfree` and `insecure` come
        ready in `yen.lib.batteries.nixos` (see [NixOS batteries](/batteries/nixos/)), and you can write your own for the others.
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
      hosts = eq (builtins.attrNames result.flake.nixosConfigurations) ([ "box" ]);
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
      c = flake.nixosConfigurations.box.config;
    in
    {
      hostname = eq (c.networking.hostName) ("box");
      shell = {
        t1 = eq (c.users.users.ana.shell.pname) ("fish");
        t2 = yes (c.programs.fish.enable);
      };
      default-shell = eq (c.users.users.bob.shell.pname) ("bash-interactive");
      autologin = eq (c.services.getty.autologinUser) ("ana");
      account = {
        t1 = eq (c.users.users.ana.description) ("Ana");
        t2 = yes (builtins.elem "wheel" c.users.users.ana.extraGroups);
      };
      account-only-ana = {
        t1 = no ((builtins.elem "wheel" c.users.users.bob.extraGroups));
        t2 = yes (c.users.users.bob.isNormalUser);
      };
      insecure = eq (builtins.sort builtins.lessThan c.nixpkgs.config.permittedInsecurePackages) ([
        "olm-3.2.16"
        "python-2.7.18.8"
      ]);
    };
}
