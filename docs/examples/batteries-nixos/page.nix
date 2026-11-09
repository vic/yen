{
  title = "NixOS batteries";
  description = "yen.lib.batteries.nixos: system, accounts, shells, autologin, unfree, firewall, hosts, builders, persist, facter. They set NixOS options; the Yen keys are yours.";
  section = "batteries";
  route = "batteries/nixos";
  order = 3;

  body =
    { docs, ... }:
    [
      ''
        `yen.lib.batteries.nixos` holds the NixOS rules most fleets end up writing. NixOS is their domain, so they set
        NixOS options, but they still name no Yen [kind](/model/kinds-fields/), [sink](/behavior/sinks/) or [aspect](/behavior/aspects/).
        You write `yen.kinds.host`, the sinks and every aspect in your own words. Here's a fleet of hosts that hold users:
      ''
      (docs.fileNoted "" "modules/fleet.nix")
      ''
        - `(1)` is `system`, the `out` key of the sink that collects NixOS modules, and it builds `nixosConfigurations.<host>`.
        - `(2)` and `(3)` are the NixOS keys of two sinks of package names, where one module per host allows or marks them.
          Any aspect can give names to these sinks.

        Next, the fleet data and the aspect that gives the hosts their NixOS base:
      ''
      (docs.file "modules/machines.nix")
      ''
        These aspects set the host name, the users and their shells:
      ''
      (docs.fileNoted "" "modules/aspects.nix")
      ''
        Each battery is the value of an aspect's `nixos` key. `(1)` sets the host name from the [scope](/model/scopes/) name.
        `(2)` defines a user's account, and since the `user` kind has no `nixos` sink, the account goes into each of its hosts.
        `(3)` makes `ana` the primary user, `(4)` reads the `shell` field you name, and at `(5)` `user` reads a ref or a name.

        Then ports, peers and builders:
      ''
      (docs.fileNoted "" "modules/network.nix")
      ''
        `(1)` opens the ports aspects give, `22` or `{ tcp; udp; }`. At `(2)` and `(3)` every host gives a record to the fleet,
        and each host reads the other machines' records for `/etc/hosts`, `known_hosts` and `nix.buildMachines`.

        Finally, paths that survive a reboot, and hardware:
      ''
      (docs.fileNoted "" "modules/storage.nix")
      ''
        `(1)` collects paths from any aspect, for impermanence. A user's path goes up to each of its hosts. `(2)` adds a
        facter module only at hosts that have a report.

        ## The batteries

        | Battery | Value of | Den |
        |---|---|---|
        | `system { from; nixpkgs; }` | the `out` key of the sink that collects NixOS modules | the `den.hosts` schema |
        | `hostname` | a NixOS key of an aspect | `den.batteries.hostname` |
        | `define-user` | a NixOS key of an aspect | `den.batteries.define-user` |
        | `primary-user { user ? ; }` | a NixOS key; `user` reads a ref or a name, by default the scope | `den.batteries.primary-user` |
        | `unfree { from; }` | the NixOS key of a sink of package names | `den.batteries.unfree` |
        | `insecure { from; }` | the NixOS key of a sink of package names | `den.batteries.insecure` |
        | `user-shell { shell; }` | a NixOS key; `shell` reads the scope | `den.batteries.user-shell` |
        | `autologin { user; }` | a NixOS key; `user` reads a ref or a name | `den.batteries.tty-autologin` |
        | `firewall { from; }` | the NixOS key of a sink of ports (`22` or `{ tcp; udp; }`) | quirks `firewall` |
        | `hosts { from; }` | a NixOS key; /etc/hosts and known_hosts of the other machines (`mesh`) | sini hostsfile |
        | `remote-builders { from; systemOf; }` | a NixOS key; `nix.buildMachines` of the other machines (`mesh`) | sini remote-build-client |
        | `persist { from; root; hideMounts; }` | the NixOS key of a sink of paths (impermanence) | quirks `persist` |
        | `facter { report; module; }` | a NixOS key, at hosts that have a report | `den.aspects.facter` |

        `mesh` is a [generic battery](/batteries/generic/). Each battery is only a few lines, and the pages [Every Den battery](/den/batteries/) and
        [Unfree packages from many files](/nixos/unfree/) write the same rules by hand. When a battery doesn't fit your
        fleet, copy those lines and change them (see [Write your own](/batteries/generic/#write-your-own)).
      ''
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
      hosts = eq (builtins.attrNames result.flake.nixosConfigurations) ([
        "desk"
        "nas"
      ]);
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
      c = flake.nixosConfigurations.desk.config;
      nas = flake.nixosConfigurations.nas.config;
      ok = p: (builtins.tryEval flake.nixosConfigurations.desk.pkgs.${p}.drvPath).success;
    in
    {
      hostname = eq (c.networking.hostName) ("desk");
      accounts = {
        t1 = yes (c.users.users.ana.isNormalUser);
        t2 = eq (c.users.users.bob.home) ("/home/bob");
      };
      admin = {
        t1 = yes (builtins.elem "wheel" c.users.users.ana.extraGroups);
        t2 = no ((builtins.elem "wheel" c.users.users.bob.extraGroups));
      };
      unfree = {
        t1 = yes (ok "steam-unwrapped");
        t2 = yes (ok "vscode");
        t3 = no ((ok "zoom-us"));
      };
      insecure = eq (c.nixpkgs.config.permittedInsecurePackages) ([ "olm-3.2.16" ]);
      shell = {
        t1 = eq (c.users.users.ana.shell.pname) ("fish");
        t2 = yes (c.programs.fish.enable);
        t3 = yes (c.users.users.bob.shell.pname != "fish");
      };
      autologin = {
        t1 = eq (c.services.getty.autologinUser) ("ana");
        t2 = eq (nas.services.getty.autologinUser) (null);
      };
      firewall = {
        t1 = yes (builtins.elem 53 nas.networking.firewall.allowedUDPPorts);
        t2 = yes (builtins.elem 22 c.networking.firewall.allowedTCPPorts);
        t3 = no ((builtins.elem 53 c.networking.firewall.allowedTCPPorts));
      };
      hosts = {
        t1 = eq (c.networking.hosts."10.0.0.1") ([ "nas" ]);
        t2 = no ((c.networking.hosts ? "10.0.0.2"));
        t3 = eq (builtins.attrNames c.programs.ssh.knownHosts) ([ "nas" ]);
      };
      persist = {
        t1 = yes (c.environment.persistence."/persist".directories != [ ]);
        t2 = yes (
          builtins.elem "/etc/ssh/ssh_host_ed25519_key" (
            map (f: f.file) c.environment.persistence."/persist".files
          )
        );
        t3 = yes (
          builtins.elem "/home/ana/.local/share" (
            map (d: d.directory) c.environment.persistence."/persist".directories
          )
        );
        t4 = no (
          (builtins.elem "/home/ana/.local/share" (
            map (d: d.directory) nas.environment.persistence."/persist".directories
          ))
        );
        t5 = yes c.environment.persistence."/persist".hideMounts;
      };
      facter = {
        t1 = yes (nas.facter.reportPath != null);
        t2 = no ((c ? facter));
      };
      builders = {
        t1 = yes (c.nix.distributedBuilds);
        t2 = eq (map (m: m.hostName) c.nix.buildMachines) ([ "10.0.0.1" ]);
      };
    };
}
