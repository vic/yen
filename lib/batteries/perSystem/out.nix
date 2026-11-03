#: lib.batteries.perSystem.out :: { from; group; systemOf ? ; } -> out value -- a sink at a system scope, written as flake.<group>.<system>
# The value of a sink's `out` key at a scope that stands for one system: the reduced sink becomes the flake output
# `<group>.<system>`, so a fleet writes per-system outputs (packages, checks, apps, devShells) without the loop.
# `systemOf` names the system of the scope; the default is the scope name (`yen.system.x86_64-linux`).
#   yen.kinds.system.sinks.packages = { reduce = yen.lib.reduce.merge; out = perSystem.out { from = yen.kinds.system.sinks.packages; group = "packages"; }; };
_:
{
  from,
  group,
  systemOf ? scope: scope.name,
}:
{ scope, sinks, ... }:
{
  ${group}.${systemOf scope} = sinks.${from.__sink};
}
