# The fleet as data: where each host lives, its address, and the database it talks to. Nothing here configures a
# machine. Your hosts stay built the way they are built today.
{ yen, ... }:
{
  yen.kinds.fleet.spawns = {
    region = _: yen.region;
    host = _: yen.host;
  };
  yen.kinds.region = { };
  yen.kinds.host.fields = {
    addr = yen.lib.str;
    region = yen.kinds.region;
    db = yen.lib.maybe yen.kinds.host;
  };

  yen.fleet.main = { };
  yen.region.eu = { };
  yen.region.us = { };
  yen.host.db = {
    addr = "10.0.0.2";
    region = yen.region.eu;
  };
  yen.host.api = {
    addr = "10.0.0.1";
    region = yen.region.eu;
    db = yen.host.db;
  };
  yen.host.backup = {
    addr = "10.0.1.1";
    region = yen.region.us;
  };
}
