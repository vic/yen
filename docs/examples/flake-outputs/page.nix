{
  title = "Flake outputs";
  description = "The root's `out` sink is the flake. Any element can read the outputs with the `out` arg.";
  section = "behavior";
  order = 8;

  body =
    { docs, result, ... }:
    [
      ''
        yen does not know what a flake is. The root [kind](/model/kinds-fields/) declares an `out` [sink](/behavior/sinks/),
        and `yen.flake` gives the flake's outputs. Each sink with an `out` key gives its part.
      ''
      (docs.fileNoted "" "modules/fleet.nix")
      ''
        `(1)` declares the `out` sink of the root, and it merges what it receives. `(2)` is a sink with an `out` key:
        it gives `services` to the flake. `(3)` makes the flake the value of that `out` sink.

        ## Read the outputs

        The `out` arg is the flake itself, read lazily. An [aspect](/behavior/aspects/) can build on other outputs without `inputs.self`:
      ''
      (docs.fileNoted "" "modules/aspects.nix")
      ''
        `(1)` asks for `out`, the [arg](/behavior/args/) that holds the flake. `(2)` reads the `services` output of the hosts.
        This is the flake:
      ''
      (docs.value result.flake)
      ''
        `checks.<system>.yen-lean` is in every flake whose `inputs` has `nixpkgs`: the [Lean checker](/query/lean/) on the
        fleet's verdict, so `nix flake check` always checks the rules.

        ## With or without flakes

        `(import yen).lib.mkFlake sinks module` gives the flake outputs. `(import yen).lib.eval module` gives every query,
        and `flake` is one of them. Each key of `sinks` is a module sink: `mkFlake sinks m` is the `flake` of a root module
        that imports `sinks` and `m`, and declares each key of `sinks` in `yen.sinks`.

        [Project layout](/start/project-layout/) shows both ways in a project. The `out` sink above uses `merge`;
        [Sinks](/behavior/sinks/) lists the reducers.
      ''
      (docs.note "Laziness closes the loop" ''
        `inventory` reads `out` and gives to `out`. There is no fixpoint to run: Nix computes a value only when something reads it,
        and `inventory` never reads itself.
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
      flake = eq (removeAttrs result.flake [ "checks" ]) ({
        inventory = [
          "postgres"
          "nginx"
        ];
        services = {
          db = [ "postgres" ];
          web = [ "nginx" ];
        };
      });
    };
}
