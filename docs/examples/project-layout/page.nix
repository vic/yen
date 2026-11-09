let
  query = inputs: dir: import (dir + "/default.nix") { inherit (inputs) yen nixpkgs import-tree; };
in
{
  title = "Project layout";
  description = "One module tree, two entry points: a flake, or plain Nix with default.nix.";
  section = "start";
  order = 5;

  body =
    { docs, ... }:
    [
      ''
        A Yen project is one directory of files. Here's the template's layout:
      ''
      docs.tree
      ''
        `modules/` is the fleet. Every file in it is a [module](/principles/modules/), so put each
        [kind](/model/kinds-fields/), feature or host in its own file and move files around freely. File order never
        changes a result.

        Yen reads one module, which can be a path, a function or an attrset, with the keys `imports`, `yen` and
        [sinks](/behavior/sinks/). Yen doesn't know what `inputs` or `lib` are. The root module gives them as sinks and
        declares them in `yen.sinks` (you'll see this in `default.nix` below), and any file can ask for them as args.
        The [glossary](/reference/glossary/) explains each term.

        ## Two entry points

        The same `modules/` can be used two ways:
      ''
      (docs.tabs [
        {
          label = "flake.nix";
          body = docs.file "flake.nix";
        }
        {
          label = "default.nix";
          body = docs.file "default.nix";
        }
      ])
      ''
        `mkFlake` gives the flake outputs, and `eval` gives every query, `flake` included. Both read the same `modules/`.
      ''
      (docs.file "query.nix")
      (docs.sh ''
        nix eval --impure --file query.nix errors          # [ ] when the fleet is valid
        nix eval --impure --file query.nix graph.scopes    # every scope
        nix build -f query.nix flake.nixosConfigurations.laptop.config.system.build.toplevel
      '')
      ''
        ## NixOS without the nixpkgs flake

        `nixpkgs.lib.nixosSystem` only exists on the nixpkgs flake, but `nixos/lib/eval-config.nix` works with a flake
        input and with a plain path, so one host file serves both entry points:
      ''
      (docs.fileNoted "" "modules/host.nix")
      ''
        At `(1)`, the host imports `eval-config.nix` from the `nixpkgs` input, whether `nixpkgs` is a flake input or a
        plain path.
      ''
      (docs.caution "Args are explicit" ''
        Yen only gives a module `yen` and the sinks that modules give or declare. A file asking for `pkgs` at the top
        level gets an error record, because `pkgs` belongs to NixOS. Ask for it inside a `nixos` element.
      '')
    ];

  checks =
    {
      inputs,
      dir,
      result,
      eq,
      yes,
      no,
      ...
    }:
    {
      same-queries = {
        t1 = eq ((query inputs dir).errors) ([ ]);
        t2 = eq ((query inputs dir).graph) (result.graph);
      };
    };
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
    {
      same-system = eq ((query inputs dir).flake.nixosConfigurations.laptop.config.system.build.toplevel.drvPath) (
        flake.nixosConfigurations.laptop.config.system.build.toplevel.drvPath
      );
    };
}
