{
  title = "Platform batteries";
  description = "NixOS, nix-darwin, home-manager, nix-on-droid and microvm.nix: each kind builds its output with a battery; homes go into machines.";
  section = "batteries";
  route = "batteries/platforms";
  order = 2;

  body =
    { docs, ... }:
    [
      ''
        Each platform is a [kind](/model/kinds-fields/) you declare, with a [sink](/behavior/sinks/) that collects its modules. A battery turns the sink into the
        flake output. The builders and `pkgs` are roles that read the [scope](/model/scopes/), so each machine can use its own channel.
        This fleet has a NixOS host with a guest, a mac, a phone and a standalone home:
      ''
      (docs.fileNoted "" "modules/fleet.nix")
      ''
        - `(1)` builds `nixosConfigurations.<name>` from the `nixos` sink of a host.
        - `(2)` turns a sink of modules into one module. A user's home goes into the NixOS host this way.
        - `(3)` is a guest. Its NixOS config goes into its host as `microvm.vms.<guest>`.
        - `(4)` builds `darwinConfigurations.<name>`.
        - `(5)` builds `nixOnDroidConfigurations.<name>`, and `(6)` gives the phone's home-manager config to it.
        - `(7)` builds `homeConfigurations.<name>` for a standalone home.
        - `(8)` gives a user's home to the machine the user is on, as `home-manager.users.<user>.imports`.

        The machines, and the aspects that give them their configuration:
      ''
      (docs.fileNoted "" "modules/machines.nix")
      ''
        `(1)` is a battery too: it gives the NixOS host home-manager with the machine's `pkgs`. `(2)` sets `system.primaryUser` on the mac.
        `(3)` installs homebrew casks, brews and masApps from a sink.
      ''
      (docs.note "What the checks prove" ''
        Each output evaluates for real. ana's git is on in her home inside the NixOS host, inside the mac and on her
        laptop. The guest is a microvm of the host. The mac installs firefox with homebrew and its primary user is ana.
      '')
      ''
        ## The batteries

        | Battery | Value of | Gives |
        |---|---|---|
        | `configurations { from; output; build; }` | `out` of any module sink | `<output>.<scope name> = build scope modules` |
        | `nixos.system { from; nixpkgs; }` | `out` of the NixOS sink | `nixosConfigurations.<name>` |
        | `darwin.system { from; darwinSystem; system; }` | `out` of the darwin sink | `darwinConfigurations.<name>` |
        | `darwin.primary-user { user ? ; }`, `darwin.homebrew { from; }` | darwin keys | `system.primaryUser`; homebrew from a sink of casks, brews, masApps |
        | `home-manager.system { from; homeManagerConfiguration; pkgs; }` | `out` of a home's sink | `homeConfigurations.<name>` |
        | `home-manager.into-host { from; }` | a user sink's key that gives to the machine | `home-manager.users.<user>.imports` |
        | `home-manager.module module` | a machine key | home-manager with the machine's pkgs |
        | `droid.system { from; nixOnDroidConfiguration; pkgs; }`, `droid.home { from; }` | phone sinks | `nixOnDroidConfigurations.<name>`, its home-manager config |
        | `microvm.guest { from; pkgs; }` | a guest sink's key that gives to the host | `microvm.vms.<guest>` of the host |
        | `imports { from; }` | a sink's key | the sink's modules as one module |

        `configurations` is the generic battery behind the platform builders. See [Generic batteries](/batteries/generic/).
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
      outputs = eq (builtins.attrNames (builtins.removeAttrs result.flake [ "checks" ])) ([
        "darwinConfigurations"
        "homeConfigurations"
        "nixOnDroidConfigurations"
        "nixosConfigurations"
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
      server = flake.nixosConfigurations.server.config;
      studio = flake.darwinConfigurations.studio.config;
      laptop = flake.homeConfigurations.ana-laptop.config;
    in
    {
      nixos = yes (builtins.isString server.system.build.toplevel.drvPath);
      home-in-nixos = yes (server.home-manager.users.ana.programs.git.enable);
      guest = eq (server.microvm.vms.ci.config.config.networking.hostName) ("ci");
      darwin = yes (builtins.isString studio.system.build.toplevel.drvPath);
      home-in-darwin = yes (studio.home-manager.users.ana.programs.git.enable);
      homebrew = {
        t1 = yes (studio.homebrew.enable);
        t2 = eq (map (c: c.name) studio.homebrew.casks) ([ "firefox" ]);
      };
      primary-user = eq (studio.system.primaryUser) ("ana");
      home = {
        t1 = yes (laptop.programs.git.enable);
        t2 = yes (builtins.isString laptop.home.activationPackage.drvPath);
      };
      droid = yes (flake.nixOnDroidConfigurations.pixel.config.home-manager.config.programs.git.enable); # config only: the drv needs an Android build
    };
}
