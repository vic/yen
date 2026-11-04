# The engine entry: `eval` (a fixpoint over the parts in lib/_eval/), `mkFlake`, and the agent surface outside an eval
# (lib/_agents/). Builtins only. No throws: an error is an emission. No merge, no module system: every read is a query
# on the files that answer it.
# Entry: `(import ./default.nix).lib.eval module`. A module is a path, a function or an attrset; `imports` nest; each key is a sink, each arg is a source.
self:
let
  inherit (self._prelude)
    b
    datalog
    graphs
    _impact
    uKanren
    mapAttrs
    rdf
    static
    ;

  #: lib.eval :: module -> result -- evaluate a fleet module; the result answers every query
  # one fixpoint per eval: the state `st` holds the names every part of lib/_eval/ gives, the prelude, `root` and
  # `tools`; the answer is its `self`
  eval =
    root:
    (self._core.fix (
      st:
      b.foldl' (acc: p: acc // p st) (self._prelude // { inherit root tools; }) (b.attrValues self._eval)
    )).self;
  # the agent surface outside an eval: lib/_agents/
  inherit (self._agents.grants) grants;
  inherit (self._agents.stage) stage;
  inherit (self._agents.history) diffData asOf history;
  inherit (self._agents.without) without;
  inherit (self._agents.program) program change;
  # agent tools: the engine library outside an eval, and inside the fleet too
  tools = static // {
    inherit
      graphs
      rdf
      datalog
      uKanren
      stage
      change
      program
      diffData
      without
      ;
    inherit (grants) grant narrow allowed;
    inherit (self) batteries kits; # kits: ready-made modules a fleet imports
  };
in
{
  # the public names are listed in lib/api.nix
  inherit (grants) grant narrow allowed;
  inherit
    eval
    asOf
    history
    stage
    change
    program
    diffData
    without
    ;
  #: lib.mkFlake :: sinks -> module -> flake -- the flake outputs of the fleet, or { invalid-flake-errors } when it has an error or a violation.
  # `sinks` is a root module: each of its keys but `imports` and `yen` is a module sink, declared for you
  mkFlake =
    sinks: m:
    (eval {
      imports = [
        sinks
        {
          yen.sinks = mapAttrs (_: _: { }) (
            removeAttrs sinks [
              "imports"
              "yen"
            ]
          );
        }
        m
      ];
    }).flake;
}
