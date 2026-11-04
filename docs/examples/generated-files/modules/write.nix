# README.md and the CI workflow, generated from fleet data by github:sini/files.
{ yen, lib, ... }:
let
  whole.graph = true; # (1) a tree request: the whole fleet
  fleetOf = tree: builtins.head (tree.select whole); # the whole fleet, with its data
  hostsIn = fleet: lib.filter (s: fleet.lib.holds fleet.kinds.host s) fleet.lib.graph.scopes;
  hostsOf = tree: hostsIn (fleetOf tree);
in
{
  yen.aspects.write = {
    at = yen.kinds.fleet;
    cycle =
      { tree, ... }:
      {
        tree = [ whole ]; # (2)
        files = [
          # (3)
          {
            files.file."README.md".text = ''
              # My fleet

              Generated from the fleet. Hosts: ${lib.concatMapStringsSep ", " (s: "`${s.name}`") (hostsOf tree)}.

              ```mermaid
              graph TD
                fleet[main]
              ${lib.concatMapStringsSep "\n" (s: "  fleet --> ${s.name}") (hostsOf tree)}
              ```
            '';
            files.file.".github/workflows/ci.yml".text = ''
              name: ci
              on: [push, pull_request]
              jobs:
                check:
                  runs-on: ubuntu-latest
                  steps:
                    - uses: actions/checkout@v4
                    - uses: DeterminateSystems/nix-installer-action@main
                    - run: nix flake check
            '';
          }
        ];
      };
  };
}
