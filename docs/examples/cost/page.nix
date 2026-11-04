{
  title = "What yen costs";
  description = "The engine is linear in aspect refs and receivers, and its cost oracles keep it so.";
  section = "perf";
  order = 2;

  body =
    { docs, ... }:
    [
      ''
        yen is one file of Nix builtins. Its own cost is small next to nixpkgs and the module system, and it stays
        small as a fleet grows:

        - Each [scope](/model/scopes/) computes each [aspect](/behavior/aspects/) ref once, so aspects that read aspects cost linear time, however deep they nest.
        - [Sinks](/behavior/sinks/) are lazy per receiver. A sink that nobody reads costs nothing.
        - Declarations are one lazy index over every file: a lookup walks its path, never all files.
      ''
      (docs.table
        [ "Cost oracle (`tests/cost.sh`)" "Bound" "Without the memo" ]
        [
          [
            "30 levels of aspect-ref diamonds"
            "under 200,000 function calls"
            "26 million calls at 16 levels"
          ]
          [
            "a 150-host fan-in"
            "under 200,000 function calls"
            "954,000 calls"
          ]
        ]
      )
      ''
        A memo is invisible to an eval, so the oracle ([tests/cost.sh](https://github.com/vic/yen/tree/main/tests/cost.sh))
        bounds Nix's own counters (`NIX_SHOW_STATS`), not wall time.
        The engine evaluates 10,000 modules in about 20 s.
      ''
      (docs.sh ''
        engine-test                                       # every suite of tests/, through tests.nix
        bash tests/cost.sh                                # PASS aspect-ref-memo, PASS reduction-memo
      '')
      (docs.tip "Where the time goes" ''
        On a real host, nixpkgs and the NixOS module system are most of the evaluation. See [Shared pkgs](/perf/shared-pkgs/)
        and [Trimmed module lists](/perf/trimmed-modules/).
      '')
    ];
}
