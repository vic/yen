{
  title = "From configuration.nix";
  description = "Move a single /etc/nixos/configuration.nix to Yen and build the same system.";
  section = "migrate";
  order = 1;
  badge = "start here";

  body =
    { docs, ... }:
    [
      ''
        You have one machine and one `configuration.nix`, and this page moves it to Yen. The result builds the
        **same system**: the docs check that both give the same toplevel `drvPath`.
      ''
      (docs.tabs [
        {
          label = "Before: configuration.nix";
          body = docs.file "before/configuration.nix";
        }
        {
          label = "hardware-configuration.nix";
          body = docs.file "before/hardware-configuration.nix";
        }
      ])
      ''
        ## What changes

        A `configuration.nix` mixes three things: data (the host name, the users), features (ssh, tools),
        and generated hardware. Yen keeps them apart. The steps below show each part, and the table after them
        maps each line of `configuration.nix` to its Yen form.
      ''
      (docs.steps [
        ''
          Get the template, and copy your two files over the ones in `machines/laptop/`:

          ${docs.sh "nix flake init -t github:vic/yen#from-configuration-nix"}
        ''
        ''
          Declare the fleet:

          ${docs.fileNoted "" "modules/fleet.nix"}

          `(1)` says a user lives under the hosts in its `hosts` field ([scopes](/model/scopes/)).
          `(2)` is a host's `nixos` [sink](/behavior/sinks/), which builds the NixOS system from the modules it
          collected. `(3)` is a user [field](/model/kinds-fields/), a list of group names that's empty by default.
        ''
        ''
          Declare your machine and your people as data:

          ${docs.file "modules/laptop.nix"}
        ''
        ''
          Move each part of `configuration.nix` to an [aspect](/behavior/aspects/), each one active at every host:

          ${docs.file "modules/features/machine.nix"}

          ${docs.file "modules/features/ssh.nix"}

          ${docs.file "modules/features/tools.nix"}
        ''
        ''
          Give accounts from user data:

          ${docs.fileNoted "" "modules/features/accounts.nix"}

          `(1)` makes the aspect active at every user. `(2)` is the user, since Yen fills `user` with the nearest user.
          A user has no `nixos` sink, so the account goes up to the host.
        ''
        ''
          Switch:

          ${docs.sh "sudo nixos-rebuild switch --flake .#laptop"}
        ''
      ])
      ''
        ## Where each line went
      ''
      (docs.table
        [ "In configuration.nix" "In Yen" ]
        [
          [
            "`networking.hostName = \"laptop\"`"
            "the instance `yen.host.laptop`: the name is data"
          ]
          [
            "`users.users.alice = …`"
            "the instance `yen.user.alice`, and one `account` aspect for every user"
          ]
          [
            "`services.openssh.enable = true`"
            "an aspect, active at every host"
          ]
          [
            "`imports = [ ./hardware-configuration.nix ]`"
            "`machines/<name>/hardware-configuration.nix`, found by name"
          ]
        ]
      )
      (docs.tip "Do it in two steps" ''
        You don't have to split everything on day one, because one aspect can give the whole old file.
        With only `modules/fleet.nix` and `modules/laptop.nix`, this builds the same system too:

        ${docs.file "variants/legacy.nix"}

        Then move one part at a time to its own aspect, and compare the `drvPath` after each move.
      '')
      ''
        ## Your second machine

        Add `yen.host.desktop = { };`, its `machines/desktop/hardware-configuration.nix`, and `yen.host.desktop`
        to each user's `hosts`. Every aspect above is active there too. Next, read [From a flake](/migrate/from-flake/).
      ''
    ];

  e2e =
    {
      inputs,
      dir,
      flake,
      only,
      eq,
      yes,
      no,
      ...
    }:
    {
      step-one = eq ((only [
        "modules/fleet.nix"
        "modules/laptop.nix"
        "variants/legacy.nix"
      ]).flake.nixosConfigurations.laptop.config.system.build.toplevel.drvPath
      ) (flake.nixosConfigurations.laptop.config.system.build.toplevel.drvPath);
      same-system = eq ((inputs.nixpkgs.lib.nixosSystem {
        modules = [ (dir + "/before/configuration.nix") ];
      }).config.system.build.toplevel.drvPath
      ) (flake.nixosConfigurations.laptop.config.system.build.toplevel.drvPath);
    };
}
