# A small homelab: three machines in two zones, and the services on them. A service points at its machine.
{ yen, ... }:
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.host = {
    fields = {
      addr = yen.lib.str;
      zone = yen.lib.enum [
        "prod"
        "dev"
      ];
      backup = yen.lib.opt (yen.lib.enum [
        "nightly"
        "none"
      ]) "nightly";
    };
    spawns.service = yen.lib.pointing "on" yen.service;
  };
  yen.kinds.service.fields = {
    on = yen.kinds.host;
    port = yen.lib.int;
    reach = yen.lib.opt (yen.lib.enum [
      "lan"
      "internet"
    ]) "lan";
  };

  yen.fleet.main = { };
  yen.host.edge = {
    addr = "10.0.0.1";
    zone = "prod";
  };
  yen.host.db1 = {
    addr = "10.0.0.2";
    zone = "prod";
  };
  yen.host.lab = {
    addr = "10.0.1.1";
    zone = "dev";
  };

  yen.service.proxy = {
    on = yen.host.edge;
    port = 443;
    reach = "internet";
  };
  yen.service.postgres = {
    on = yen.host.db1;
    port = 5432;
  };
  yen.service.metrics = {
    on = yen.host.db1;
    port = 9100;
  };

  yen.aspects.database.at = yen.service.postgres;
  yen.aspects.prod-credentials.at = yen.host.edge;
  yen.flake = { out, ... }: out;
}
