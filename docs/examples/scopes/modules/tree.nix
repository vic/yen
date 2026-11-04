# `spawns.<kind>` gives the children of a scope: a function of the parent scope.
{ yen, ... }:
{
  yen.kinds.fleet.spawns.environment = _: yen.environment; # (1)
  yen.kinds.environment.spawns.host = yen.lib.pointing "environment" yen.host; # (2)
  yen.kinds.host = {
    fields.environment = yen.kinds.environment;
    spawns.user = yen.lib.pointing "hosts" yen.user; # (3)
  };
  yen.kinds.user.fields.hosts = yen.lib.listOf yen.kinds.host; # refs to the hosts the user logs in to

  yen.fleet.main = { };
}
