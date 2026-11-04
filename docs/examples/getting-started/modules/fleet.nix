# The root of the tree. Nothing spawns it. Its `out` sink is the flake.
{ yen, ... }:
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host; # (1)
    sinks.out.reduce = yen.lib.reduce.merge; # (2)
  };
  yen.fleet.main = { };
  yen.flake = { out, ... }: out; # (3)
}
