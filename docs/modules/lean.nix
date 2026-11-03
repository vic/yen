# The Lean checker in the docs flake: the app, and two checks on the example of the "Verified by Lean" page. The clean
# fleet must verify, and the fleet with its mistakes must be rejected (exit 1): `docs-check` builds both in CI.
{
  yen,
  inputs,
  ...
}:
let
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  dir = ../examples/lean;
  example =
    extra:
    inputs.yen.lib.eval {
      imports = [
        {
          yen.sinks = {
            inputs = { };
            lib = { };
          };
        }
        (inputs.import-tree (dir + "/modules"))
      ]
      ++ extra;
      inherit inputs;
      inherit (inputs.nixpkgs) lib;
    };
  checkerOf = system: inputs.nixpkgs.legacyPackages.${system}.callPackage ../../lean/package.nix { };
  inherit (inputs.yen.lib.batteries.lean) systems;
in
{
  yen.aspects.lean = {
    at = yen.kinds.site;
    out = {
      packages = inputs.nixpkgs.lib.genAttrs systems (system: {
        yen-cert-check = checkerOf system;
      });
      apps = inputs.nixpkgs.lib.genAttrs systems (system: {
        yen-cert-check = {
          type = "app";
          program = "${checkerOf system}/bin/yen-cert-check";
          inherit (checkerOf system) meta;
        };
      });
      checks.x86_64-linux = {
        lean-example = inputs.yen.lib.batteries.lean.verify {
          inherit pkgs;
          result = example [ ];
        };
        # deploy waves: an order that verifies, and a cycle the checker must reject
        lean-waves = inputs.yen.lib.batteries.lean.waves {
          inherit pkgs;
          succ = {
            web = [ "db" ];
            db = [ "net" ];
            net = [ ];
          };
        };
        lean-waves-cycle =
          pkgs.runCommand "lean-waves-cycle"
            {
              nativeBuildInputs = [ (checkerOf "x86_64-linux") ];
              waves = builtins.toJSON {
                edges = [
                  [
                    "a"
                    "b"
                  ]
                  [
                    "b"
                    "a"
                  ]
                ];
                layers = inputs.yen.lib.graphs.layers {
                  a = [ "b" ];
                  b = [ "a" ];
                };
              };
              passAsFile = [ "waves" ];
            }
            ''
              code=0
              yen-cert-check --waves "$wavesPath" || code=$?
              [ "$code" = 1 ] || { echo "expected the checker to reject a cycle (exit 1), got exit $code" >&2; exit 1; }
              touch "$out"
            '';
        lean-example-mistakes =
          pkgs.runCommand "lean-example-mistakes"
            {
              nativeBuildInputs = [ (checkerOf "x86_64-linux") ];
              verdict = builtins.toJSON (example [ (dir + "/variants/mistakes.nix") ]).check.lean;
              passAsFile = [ "verdict" ];
            }
            ''
              code=0
              yen-cert-check "$verdictPath" || code=$?
              [ "$code" = 1 ] || { echo "expected the checker to reject (exit 1), got exit $code" >&2; exit 1; }
              touch "$out"
            '';
      };
    };
  };
}
