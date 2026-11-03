{ yen, lib, ... }:
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.environment.fields.domain = yen.lib.str;
  yen.kinds.host = {
    fields.environment = yen.kinds.environment;
    sinks.services = { };
  };
  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
}
