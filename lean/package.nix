# yen-cert-check: the Lean checker of yen verdicts (Main.lean), compiled. Built by the top-level flake and the docs
# flake from the nixpkgs pinned in docs/flake.lock.
{ stdenv, lean4 }:
stdenv.mkDerivation {
  pname = "yen-cert-check";
  version = "0.1.0";
  src = ./.;
  nativeBuildInputs = [ lean4 ];
  buildPhase = "HOME=$TMPDIR lake build yen-cert-check";
  installPhase = "install -Dm755 .lake/build/bin/yen-cert-check $out/bin/yen-cert-check";
  meta = {
    description = "Lean checker of a yen verdict: result.check.lean as JSON";
    mainProgram = "yen-cert-check";
  };
}
