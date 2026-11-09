{
  title = "Custom classes and forward";
  description = "den.batteries.forward and den.classes: a sink whose other keys give its content to a class, at a path.";
  section = "den";
  route = "den/classes";
  order = 4;

  body =
    { docs, ... }:
    [
      ''
        In Den, a custom class is a new [aspect](/behavior/aspects/) key, like `nix` or `persist`, and
        `den.batteries.forward` sends its content into another class at a path, with `fromClass`, `intoClass`,
        `intoPath` and `adaptArgs`. It's the fifth most used battery in public Den configurations.

        In Yen a custom class is a [sink](/behavior/sinks/), and aspects give elements to it by name. The sink's other
        keys give the reduced content to other sinks, like `nixos` or `homeManager`, and the function places it at any
        path. There's no `adaptArgs`, since the function gets Yen args and the content is plain data.
      ''
      (docs.table
        [ "Den forward" "Yen sink" ]
        [
          [
            "`den.classes.nix`"
            "`yen.kinds.<kind>.sinks.nix`"
          ]
          [
            "`fromClass = _: \"nix\"`"
            "the sink name"
          ]
          [
            "`intoClass`, `each = [ \"nixos\" \"homeManager\" ]`"
            "one key per target, on each [kind](/model/kinds-fields/) that has the sink"
          ]
          [
            "`intoPath = _: [ \"nix\" \"settings\" ]`"
            "the attribute path in the key's function"
          ]
          [
            "`adaptArgs`"
            "not needed: Yen args, like `host`, are args of the key's function"
          ]
        ]
      )
      ''
        ## One class, two targets

        The same `nix` settings go to NixOS's `nix.settings` on hosts, and to home-manager's on standalone homes. The
        hosts and homes are declared in the `fleet.nix` tab below.
      ''
      (docs.fileNoted "" "modules/nix.nix")
      ''
        `(1)` declares the `nix` sink on the `host` kind, and the `home` kind has its own. `(2)` is the sink's `nixos`
        key, which gives the reduced settings to the `nixos` sink. `(3)` is a single aspect giving `nix` elements to every
        host and every home, so the settings are written once.

        ## A class under a path

        This is also the *DRY aspect* from the
        [dendritic design guide](https://github.com/Doc-Steve/dendritic-design-with-flake-parts/wiki/Dendritic_Aspects),
        for options inside an attribute set of submodules.
      ''
      (docs.fileNoted "" "modules/lan.nix")
      ''
        A feature writes `lan` content, as at `(3)`. The `lan` sink at `(1)` puts it under the interface the host names
        in its `lan` field, using `lib.mkMerge` at `(2)` so two features never overwrite each other.
      ''
      (docs.tabs [
        {
          label = "fleet.nix";
          body = docs.file "modules/fleet.nix";
        }
      ])
      (docs.tip "More classes" ''
        The reference fleet has a `git` user sink that forwards into `homeManager`, and a `maid` sink that writes
        dotfiles without home-manager: ${
          docs.fleet "modules/den/custom-classes.nix" null "den/custom-classes.nix"
        }.
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
        t1 = eq (builtins.attrNames result.flake.nixosConfigurations) ([ "server" ]);
        t2 = eq (builtins.attrNames result.flake.homeConfigurations) ([ "ana" ]);
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
      os = flake.nixosConfigurations.server.config;
      hm = flake.homeConfigurations.ana.config;
      lan = os.networking.interfaces.enp86s0;
    in
    {
      nixos = {
        t1 = yes (builtins.elem "flakes" os.nix.settings.experimental-features);
        t2 = eq (os.nix.settings.max-jobs) (4);
      };
      home = {
        t1 = yes (builtins.elem "flakes" hm.nix.settings.experimental-features);
        t2 = no ((hm.nix.settings ? max-jobs));
      };
      path = {
        t1 = eq (map (r: r.address) lan.ipv4.routes) ([ "192.168.2.0" ]);
        t2 = eq (map (a: a.address) lan.ipv4.addresses) ([ "10.0.0.1" ]);
      };
    };
}
