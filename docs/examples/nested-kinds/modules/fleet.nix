# The root kind. Its `report` sink collects one line per user and gives them to the flake.
{ yen, ... }:
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
    sinks.report = {
      reduce = yen.lib.reduce.list;
      out =
        { report, ... }:
        {
          inherit report;
        };
    };
  };
  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
}
