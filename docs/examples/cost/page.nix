{
  title = "What Yen costs";
  description = "The engine grows linearly with aspect refs and receivers, and its cost tests keep it that way.";
  section = "perf";
  order = 2;

  body =
    { docs, ... }:
    [
      ''
        Yen is one file of Nix builtins. Next to nixpkgs and the module system its own cost is small, and it stays small
        as your fleet grows:

        - Each [scope](/model/scopes/) computes each [aspect](/behavior/aspects/) ref only once, so aspects that read other aspects take linear time, however deep they nest.
        - [Sinks](/behavior/sinks/) are lazy for each receiver. A sink nobody reads costs nothing.
        - Declarations live in one lazy index over every file, so a lookup walks its own path and never all the files.
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
        You can't see a memo from inside an eval, so the cost test ([tests/cost.sh](https://github.com/vic/yen/tree/main/tests/cost.sh))
        puts a bound on Nix's own counters (`NIX_SHOW_STATS`) instead of wall time.
        For scale, the engine evaluates 10,000 modules in about 20 s.
      ''
      (docs.sh ''
        engine-test                                       # every suite of tests/, through tests.nix
        bash tests/cost.sh                                # PASS aspect-ref-memo, PASS reduction-memo
      '')
      (docs.tip "Where the time goes" ''
        On a real host, most of the evaluation is nixpkgs and the NixOS module system. See [Shared pkgs](/perf/shared-pkgs/)
        and [Trimmed module lists](/perf/trimmed-modules/) for how to cut it down.
      '')
    ];
}
