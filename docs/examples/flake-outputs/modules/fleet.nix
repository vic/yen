# The `out` sink of the root is the flake: `yen.flake` gives it.
{ yen, ... }:
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge; # (1)
  };
  yen.kinds.host.sinks.services.out = # (2)
    { host, services, ... }:
    {
      services.${host.name} = services;
    };
  yen.fleet.main = { };
  yen.host.web = { };
  yen.host.db = { };
  yen.flake = { out, ... }: out; # (3)
}
