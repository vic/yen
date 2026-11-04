{
  title = "Getting started";
  description = "One NixOS host, from an empty directory, in four files.";
  section = "start";
  order = 3;

  body =
    { docs, result, ... }:
    [
      ''
        This page builds one NixOS host with yen. You write four small files. At the end you have a
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

          The `yen` input is a normal flake input.
          [import-tree](https://github.com/denful/import-tree) loads every file in `modules/`.
        ''
        ''
          Build the host:

          ${docs.sh "nix build .#nixosConfigurations.laptop.config.system.build.toplevel"}
        ''
      ])
      ''
        ## The fleet

        yen has no built-in kinds. You say what a fleet is. This file declares the first kind, the root:
      ''
      (docs.fileNoted "" "modules/fleet.nix")
      ''
        `fleet` is a [kind](/model/kinds-fields/) (see the [glossary](/reference/glossary/)). Nothing
        [spawns](/model/scopes/) it, so it is the root. At `(1)`, the root spawns every `host`. At `(2)`, its `out`
        [sink](/behavior/sinks/) merges all the elements it gets. At `(3)`, the flake takes that `out` value.

        ## The host

        A kind has fields and sinks. A field is the data of each instance. A sink is where behavior goes.
        This kind has one field and one sink:
      ''
      (docs.fileNoted "" "modules/host.nix")
      ''
        `(1)` is a field: every host has a `system`, and it must be a string. `(2)` is the `out` function of the `nixos` sink.
        It gives the built system to the flake. yen fills `host` and `nixos` for you. At `(3)`, every NixOS module
        the sink collected goes to `nixosSystem`.

        ## Behavior

        An [aspect](/behavior/aspects/) is behavior. It is active where a predicate holds:
      ''
      (docs.fileNoted "" "modules/aspects.nix")
      ''
        `at` is the predicate. At `(1)`, `base` is active at every host. At `(4)`, `motd` is active at `laptop` only.
        At `(2)`, the key `nixos` gives one element to the sink of that name. At `(3)`, the element asks for `host`.
      ''
      (docs.note "Args are filled for you" ''
        `{ host, ... }:` asks yen for the nearest host. yen fills it, and the rest of the function stays a normal NixOS module.
      '')
      ''
        ## Ask it

        yen checks the fleet and answers. This is the scope tree of this example, generated from `result.graph`:
      ''
      (docs.scopes result)
      ''
        And `result.active`: which aspect is active at which scope.
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
          description = "Typed data, the first of yen's four words.";
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
