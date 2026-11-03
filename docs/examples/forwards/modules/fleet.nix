{ yen, ... }:
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.host.spawns.guest = yen.lib.pointing "on" yen.guest;
  yen.kinds.guest.fields.on = yen.kinds.host;

  yen.fleet.main = { };
  yen.host.server = { };
  yen.guest.ci.on = yen.host.server;
  yen.flake = { out, ... }: out;
}
