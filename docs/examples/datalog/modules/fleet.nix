{ yen, lib, ... }:
let
  inherit (yen.lib) opt is;
in
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.host.fields = {
    web = opt yen.types.bool false;
    maintenance = opt yen.types.bool false;
    dependsOn = opt (is builtins.isList) [ ];
  };

  yen.fleet.main = { };
  yen.host.db-1 = { };
  yen.host.db-2.maintenance = true;
  yen.host.web-1 = {
    web = true;
    dependsOn = [ yen.host.db-1 ];
  };
  yen.host.web-2 = {
    web = true;
    dependsOn = [ yen.host.db-2 ];
  };
  yen.flake = { out, ... }: out;
}
