# yen-cert-check: the Lean checker of yen verdicts (Main.lean), compiled. Its build is also the proof check: Lake
# elaborates every proof, and the check phase runs Examples.lean (accepted and mutant certificates) and fails when a
# theorem depends on `sorry`. So every build of the checker, in CI or in a user's `nix flake check`, checks the proofs.
{ stdenv, lean4 }:
stdenv.mkDerivation {
  pname = "yen-cert-check";
  version = "0.1.0";
  src = ./.;
  nativeBuildInputs = [ lean4 ];
  buildPhase = "HOME=$TMPDIR lake build yen-cert-check";
  doCheck = true;
  checkPhase = ''
    axioms=$(HOME=$TMPDIR lake env lean Examples.lean)
    echo "$axioms"
    if grep -q sorryAx <<<"$axioms"; then echo "a theorem depends on sorry" >&2; exit 1; fi
  '';
  installPhase = "install -Dm755 .lake/build/bin/yen-cert-check $out/bin/yen-cert-check";
  meta = {
    description = "Lean checker of a yen verdict: result.check.lean as JSON";
    mainProgram = "yen-cert-check";
  };
}
