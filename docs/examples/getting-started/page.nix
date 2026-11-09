{
  title = "Getting started";
  description = "One NixOS host, from an empty directory, in four files.";
  section = "start";
  order = 3;

  body =
    { docs, result, ... }:
    [
      ''
        Let's build one NixOS host with Yen. You'll write four small files, and at the end you'll have a
        `nixosConfigurations.laptop` that `nixos-rebuild` can use.
      ''
      (docs.steps [
        ''
          Get the template. It has a `flake.nix` and a `modules/` directory.

          ${docs.sh "nix flake init -t github:vic/yen#getting-started"}
        ''
        ''
          Read `flake.nix`:

          ${docs.file "flake.nix"}

          The `yen` input is a normal flake input, and
          [import-tree](https://github.com/denful/import-tree) loads every file in `modules/`.
        ''
        ''
          Build the host:

          ${docs.sh "nix build .#nixosConfigurations.laptop.config.system.build.toplevel"}
        ''
      ])
      ''
        ## The fleet

        Yen has no built-in kinds, so you get to say what a fleet is. This file declares the first kind, the root:
      ''
      (docs.fileNoted "" "modules/fleet.nix")
      ''
        `fleet` is a [kind](/model/kinds-fields/) (see the [glossary](/reference/glossary/)). Nothing
        [spawns](/model/scopes/) it, so it's the root. At `(1)`, the root spawns every `host`. At `(2)`, its `out`
        [sink](/behavior/sinks/) merges all the elements it gets, and at `(3)` the flake takes that `out` value.

        ## The host

        A kind has fields and sinks. A field is data each instance carries, and a sink is where behavior goes. This kind
        has one of each:
      ''
      (docs.fileNoted "" "modules/host.nix")
      ''
        `(1)` is a field: every host has a `system`, and it must be a string. `(2)` is the `nixos` sink's `out` function,
        which gives the built system to the flake, and Yen fills in `host` and `nixos` for you. At `(3)`, every NixOS
        module the sink collected goes to `nixosSystem`.

        ## Behavior

        An [aspect](/behavior/aspects/) is behavior, active wherever a predicate holds:
      ''
      (docs.fileNoted "" "modules/aspects.nix")
      ''
        `at` is the predicate. At `(1)`, `base` is active at every host, and at `(4)`, `motd` is active only at `laptop`.
        At `(2)`, the `nixos` key gives one element to the sink with that name, and at `(3)` the element asks for `host`.
      ''
      (docs.note "Args are filled for you" ''
        `{ host, ... }:` asks Yen for the nearest host. Yen fills it in, and the rest of the function stays a normal NixOS module.
      '')
      ''
        ## Ask it

        Yen checks the fleet and answers. Here's this example's scope tree, generated from `result.graph`:
      ''
      (docs.scopes result)
      ''
        And `result.active`, which aspect is active at which scope:
      ''
      (docs.value result.active)
      (docs.links [
        {
          title = "Project layout";
          href = "/start/project-layout/";
          description = "Flakes, no flakes, and where files go.";
        }
        {
          title = "Kinds and fields";
          href = "/model/kinds-fields/";
          description = "Typed data, the first of Yen's four words.";
        }
      ])
    ];

  checks =
    {
      result,
      eq,
      yes,
      no,
      notesOf,
      ...
    }:
    {
      # the fence marks of `docs.fileNoted`: each `# (n)` once, in order; a plain `(1)` is no note
      notes = {
        listed = eq (notesOf "a # (1)\nb # (2)\nc # (3)\nd # (3)") ''"(1)" "(2)" "(3)"'';
        gaps = eq (notesOf "a # (1)\nc # (3)") ''"(1)" "(3)"'';
        plain-text = eq (notesOf "no notes (1) here") "";
      };
      scopes = eq (map (s: s.id) result.graph.scopes) ([
        "fleet:main"
        "fleet:main/host:laptop"
      ]);
      motd-at-laptop = yes (result.active.motd."fleet:main/host:laptop");
    };

  e2e =
    {
      flake,
      eq,
      yes,
      no,
      ...
    }:
    {
      hostname = eq (flake.nixosConfigurations.laptop.config.networking.hostName) ("laptop");
      motd = eq (flake.nixosConfigurations.laptop.config.environment.etc.motd.text) ("managed by yen");
    };
}
