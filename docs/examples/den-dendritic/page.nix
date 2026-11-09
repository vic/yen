{
  title = "The dendritic aspect patterns";
  description = "The eight aspect patterns of the dendritic design guide, and the Yen form of each, with the pitfalls that go away.";
  section = "den";
  route = "den/dendritic";
  order = 2;

  body =
    { docs, ... }:
    [
      ''
        Den is one way to write dendritic Nix. The
        [dendritic design guide](https://github.com/Doc-Steve/dendritic-design-with-flake-parts/wiki/Dendritic_Aspects)
        names eight [aspect](/behavior/aspects/) patterns that keep coming back in dendritic configurations. Most Den users know them, by these
        names or by others, and this page gives the Yen form of each.

        In the guide, each pattern is a different way to write `flake.modules.<class>.<aspect>` and its `imports`. In Yen
        each pattern is an aspect, and what changes is its `at` (a [predicate](/behavior/predicates/)) or the data it reads.
      ''
      (docs.table
        [ "Pattern" "Guide" "Yen" ]
        [
          [
            "Simple"
            "a module per class"
            "an aspect with one key per class, below"
          ]
          [
            "Multi context"
            "a NixOS module adds a home module to `home-manager.sharedModules`"
            "an aspect at the users [`within`](/behavior/predicates/) the hosts that have the feature: [System and home](/nixos/system-and-home/)"
          ]
          [
            "Inheritance"
            "`imports = [ parent ]`"
            "the parent's `at` names the child aspect, below"
          ]
          [
            "Conditional"
            "`lib.mkMerge` and `lib.mkIf pkgs.stdenv.isLinux`"
            "`at` tests a fact; [`not`](/behavior/predicates/) excludes, below"
          ]
          [
            "Collector"
            "each host feature adds its part to a shared module"
            "a [sink](/behavior/sinks/) at a common parent, read back with `elements`: [Facts from other hosts](/nixos/cross-host/)"
          ]
          [
            "Constants"
            "a `generic` class module with `options.systemConstants`"
            "a field of the fleet, read as the `fleet` [arg](/behavior/args/), below"
          ]
          [
            "DRY"
            "a new class for values inside an attribute set of submodules"
            "a sink that places its content at a path: [Custom classes](/den/classes/)"
          ]
          [
            "Factory"
            "a function that returns modules, such as `user \"bob\" true`"
            "a [kind](/model/kinds-fields/) and its instances, with fields for the arguments, below"
          ]
        ]
      )
      ''
        ## The patterns in Yen

        One file holds the aspects, and the `fleet.nix` tab declares the hosts and users they apply to.
      ''
      (docs.fileNoted "" "modules/patterns.nix")
      ''
        `(1)` is the simple pattern: `at` is the `host` kind, so the aspect is active at every host.
        `(2)` is inheritance: `system-cli` is active at `srv`, and wherever `system-desktop` or `system-dev` is active.
        `(3)` is the conditional pattern: `at` is a function that tests the scope's `gpu` field.
        `(4)` excludes: `headless` is active at every host where `system-desktop` isn't active.
        `(5)` is the constants pattern: `fleet` is the arg that holds the fleet, and `adminEmail` is its field.
        `(6)` is the factory pattern: `admin` is a field of the `user` kind, so each user is one call of the factory.
      ''
      (docs.tabs [
        {
          label = "fleet.nix";
          body = docs.file "modules/fleet.nix";
        }
      ])
      ''
        ## Pitfalls that go away

        The guide warns about these. In Yen they can't happen, or they have no cause:
      ''
      (docs.table
        [ "Guide warning" "In Yen" ]
        [
          [
            "Use `lib.mkMerge`, not `//`, to merge aspect parts"
            "An aspect written in many files is read from all of them, and nothing is merged with `//`."
          ]
          [
            "Multi context plus inheritance can add the same module to `sharedModules` twice"
            "An element has one id per receiver, so a parent reached by two children is given once."
          ]
          [
            "Never use `lib.mkIf` around `imports`: infinite recursion"
            "No module looks at its own config to decide if it applies. `at` decides, before NixOS runs."
          ]
          [
            "Every host needs a `mkNixos` call"
            "The host kind builds every host: [Many hosts, one base](/nixos/hosts/)"
          ]
        ]
      )
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
        "srv"
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
      c = n: flake.nixosConfigurations.${n}.config;
      has = n: p: builtins.any (x: (x.pname or "") == p) (c n).environment.systemPackages;
    in
    {
      simple = {
        t1 = yes (has "desk" "git");
        t2 = yes (has "srv" "git");
      };
      inheritance = {
        t1 = yes (has "desk" "tmux");
        t2 = yes (has "srv" "tmux");
        t3 = yes ((c "desk").services.printing.enable);
        t4 = no ((c "srv").services.printing.enable);
      };
      once = eq (builtins.length (
        builtins.filter (x: (x.pname or "") == "tmux") (c "desk").environment.systemPackages
      )) (1);
      conditional = {
        t1 = eq ((c "desk").services.xserver.videoDrivers) ([ "nvidia" ]);
        t2 = yes ((c "srv").services.xserver.videoDrivers != [ "nvidia" ]);
      };
      exclude = {
        t1 = no ((c "srv").documentation.enable);
        t2 = yes ((c "desk").documentation.enable);
      };
      constants = eq ((c "srv").security.acme.defaults.email) ("admin@example.org");
      factory = {
        t1 = yes (builtins.elem "wheel" (c "desk").users.users.bob.extraGroups);
        t2 = eq ((c "desk").users.users.eve.extraGroups) ([ ]);
        t3 = yes ((c "srv").users.users ? eve);
        t4 = no (((c "srv").users.users ? bob));
      };
    };
}
