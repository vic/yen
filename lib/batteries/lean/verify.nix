#: lib.batteries.lean.verify :: { pkgs; result; checker ? ; } -> derivation -- a flake check that builds only when the Lean checker verifies the verdict of result
# The Lean checker (lean/Main.lean) on `result.check.lean`: Lean grounds the invariants over the facts itself, checks the
# certificate, and builds only when no violation is true or undefined (lean/Ground.lean `verify_sound`). The output is
# the checker's message. `checker` defaults to yen-cert-check built from `pkgs`.
#   checks.x86_64-linux.lean = yen.lib.batteries.lean.verify { inherit pkgs; result = yen.lib.eval module; };
_:
{
  pkgs,
  result,
  checker ? pkgs.callPackage ../../../lean/package.nix { },
}:
pkgs.runCommand "yen-lean-verdict" {
  nativeBuildInputs = [ checker ];
  verdict = builtins.toJSON result.check.lean;
  passAsFile = [ "verdict" ];
} ''yen-cert-check "$verdictPath" > "$out"''
