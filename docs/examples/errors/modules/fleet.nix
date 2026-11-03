{ yen, lib, ... }:
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
    sinks.warnings.out =
      { warnings, ... }:
      {
        inherit warnings;
      }; # messages that do not fail the fleet
  };
  yen.kinds.host.fields = {
    addr = yen.types.string;
    backup = yen.lib.opt yen.types.bool true;
  };

  yen.fleet.main = { };
  yen.host.web.addr = "10.0.0.1";
  yen.host.db.addr = "10.0.0.2";
  yen.host.scratch = {
    addr = "10.0.0.9";
    backup = false;
  };
  yen.flake = { out, ... }: out;
}
