{
  title = "System and home in one feature";
  description = "One feature with NixOS and home-manager parts: no sharedModules, no extraSpecialArgs, no mkIf on the platform.";
  section = "nixos";
  route = "nixos/system-and-home";
  order = 2;

  body =
    { docs, ... }:
    [
      ''
        A feature such as a desktop often has two parts: system configuration, and home-manager configuration for each
        user. The usual answers each have a cost:

        - `home-manager.sharedModules` in the NixOS module. It does not work for standalone home-manager, and a
          module that is imported from two features is added two times.
        - `extraSpecialArgs` to give home-manager the values that NixOS gets from `specialArgs`. You write them two
          times, and standalone home-manager needs a third copy.
        - `osConfig ? null` and `lib.mkIf (osConfig != null)`, because `osConfig` does not exist in standalone mode.
        - `lib.mkIf pkgs.stdenv.isLinux` to send a package list to the system on one machine and to the home on
          another. A `mkIf` around `imports` causes infinite recursion.

        In yen, the feature is [aspects](/behavior/aspects/). `at` says where each part goes. A user's home-manager content goes into each
        NixOS host that the user lives on. A standalone home builds its own `homeConfigurations` output.
      ''
      (docs.tabs [
        {
          label = "fleet.nix";
          body = docs.fileNoted "" "modules/fleet.nix";
        }
        {
          label = "machines.nix";
          body = docs.fileNoted "" "modules/machines.nix";
        }
      ])
      ''
        In `fleet.nix`, `(1)` is the `homeManager` [sink](/behavior/sinks/) of a user: it forwards the content to the
        `nixos` sink of each host the user lives on ([forwards](/behavior/forwards/)). `(2)` is the `homeManager` sink
        of a standalone home: it builds the `homeConfigurations` output. In `machines.nix`, `(1)` is the home `ana@work`
        of the user `ana`, and `(2)` is the aspect that every home gets.

        ## Two levels: the desktop and its users

        This is the *multi context aspect* of the
        [dendritic design guide](https://github.com/Doc-Steve/dendritic-design-with-flake-parts/wiki/Dendritic_Aspects).
        The home part is not a private module that the system part imports. It is an aspect at the users of every host
        that has the desktop. Two features that both need it do not import it two times: an aspect is given once per
        scope.
      ''
      (docs.fileNoted "" "modules/gnome.nix")
      ''
        `(1)` is the system part: it is active at the host `desk`. `(2)` makes the home part active at every user
        within a host where `gnome` is active ([predicates](/behavior/predicates/)).

        ## The same concern, a different level per machine

        On NixOS, fonts are system packages. On the work laptop there is no NixOS, so they go into the home. The two
        aspects have different `at`: `(1)` is every host, and `(2)` is every home. No module looks at `pkgs.stdenv`
        to find out where it is.
      ''
      (docs.fileNoted "" "modules/fonts.nix")
      ''
        ## Values for home-manager

        A home-manager module gets the same yen [args](/behavior/args/) as a NixOS module: the host, the user, and any
        sink. There is no `extraSpecialArgs`. To read the host's *NixOS options* from home-manager, see
        [osConfig in home-manager](/recipes/os-config/).
      ''
      (docs.fileNoted "" "modules/args.nix")
      ''
        `(1)` makes the aspect active at every user within a host. `(2)` asks for the host and the user.
      ''
      (docs.note "What the checks prove" ''
        The desk has GNOME, and ana's home on the desk has its settings. Her home on the work laptop has neither.
        Fonts are system packages on the desk, and home packages on the laptop, and never both.
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
      outputs = {
        t1 = eq (builtins.attrNames result.flake.nixosConfigurations) ([ "desk" ]);
        t2 = eq (builtins.attrNames result.flake.homeConfigurations) ([ "ana@work" ]);
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
    let
      desk = flake.nixosConfigurations.desk.config;
      onDesk = desk.home-manager.users.ana;
      work = flake.homeConfigurations."ana@work".config;
      names = ps: map (p: p.pname or p.name) ps;
      iface = c: c.dconf.settings ? "org/gnome/desktop/interface";
    in
    {
      gnome = yes (desk.services.xserver.desktopManager.gnome.enable);
      gnome-home = {
        t1 = yes (iface onDesk);
        t2 = no ((iface work));
      };
      fonts-system = yes (builtins.elem "inter" (names desk.fonts.packages));
      fonts-home = yes (builtins.elem "inter" (names work.home.packages));
      fonts-once = no ((builtins.elem "inter" (names onDesk.home.packages)));
      prompt = {
        t1 = eq (onDesk.home.sessionVariables.PROMPT_TAG) ("ana@desk");
        t2 = no ((work.home.sessionVariables ? PROMPT_TAG));
      };
    };
}
