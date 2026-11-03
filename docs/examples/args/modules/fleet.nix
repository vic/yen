{ yen, ... }:
let
  under = yen.lib.pointing "environment" yen.host;
in
{
  yen.kinds.fleet = {
    spawns.environment = _: yen.environment;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.environment = {
    spawns.host = under;
    sinks.backends = { }; # hosts give their address; a wall: it stays at the environment
  };
  yen.kinds.host = {
    fields = {
      environment = yen.kinds.environment;
      addr = yen.lib.str;
    };
    sinks.proxy.out =
      { host, proxy, ... }:
      {
        proxy.${host.name} = proxy;
      };
  };

  yen.kinds.cluster.fields = { }; # a kind that no scope here is under

  yen.fleet.main = { };
  yen.environment.prod = { };
  yen.host.lb = {
    environment = yen.environment.prod;
    addr = "10.0.0.1";
  };
  yen.host.web-1 = {
    environment = yen.environment.prod;
    addr = "10.0.0.2";
  };
  yen.host.web-2 = {
    environment = yen.environment.prod;
    addr = "10.0.0.3";
  };
  yen.flake = { out, ... }: out;
}
