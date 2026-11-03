#: lib.batteries.lean.waves :: { pkgs; succ; checker ? ; } -> derivation -- a flake check that builds only when Lean verifies the deploy waves of succ
# The waves of `succ` (lib.graphs.layers: each node in the first wave after all its successors, what it depends on),
# checked by the Lean checker (lean/Waves.lean): every node is in one wave, every dependency deploys in an earlier
# wave (`waves_respect`), so the graph has no cycle (`waves_acyclic`). A cycle leaves nodes out of every wave: the
# check fails and names them. The output is the checker's message, the waves stay `lib.graphs.layers succ`.
#   checks.x86_64-linux.waves = yen.lib.batteries.lean.waves { inherit pkgs; succ = { web = [ "db" ]; db = [ ]; }; };
self:
{
  pkgs,
  succ,
  checker ? pkgs.callPackage ../../../lean/package.nix { },
}:
pkgs.runCommand "yen-lean-waves" {
  nativeBuildInputs = [ checker ];
  waves = builtins.toJSON {
    edges = builtins.concatLists (
      builtins.attrValues (
        builtins.mapAttrs (
          from:
          map (to: [
            from
            to
          ])
        ) succ
      )
    );
    layers = self.graphs.layers succ;
  };
  passAsFile = [ "waves" ];
} ''yen-cert-check --waves "$wavesPath" > "$out"''
