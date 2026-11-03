# A rule that reads a relation decided by a Nix function. Lean cannot decide it, so the flake gets no yen-lean check.
{ yen, ... }:
{
  yen.relations.short-addr = {
    arity = 1;
    holds = ts: builtins.stringLength (builtins.head ts) < 4;
  };
  yen.invariants.no-short-addr =
    { H, X }:
    {
      bad = H;
      pos = [
        (yen.facts.host.addr H X)
        (yen.relations.short-addr X)
      ];
    };
}
