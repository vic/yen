# fleet > environment > host. The fleet says which day it is: pure evaluation has no clock.
{ yen, lib, ... }:
let
  inherit (yen.lib) same maybe;
in
{
  yen.kinds.fleet = {
    fields.today = yen.lib.str; # (1)
    spawns.environment = _: yen.environment;
    sinks.out.reduce = yen.lib.reduce.merge;
    sinks.dns.out = # (2)
      { dns, ... }:
      {
        inherit dns;
      };
  };
  yen.kinds.environment = {
    spawns.host = # (3)
      s: lib.filterAttrs (_: h: same h.environment s && yen.lib.validAt yen.fleet.main.today h) yen.host;
    sinks.backends.dns = # (4)
      { environment, backends, ... }:
      {
        ${environment.name} = backends;
      };
  };
  yen.kinds.host.fields = {
    environment = yen.kinds.environment;
    validFrom = maybe yen.lib.str; # (5) null: open, valid since always
    validTo = maybe yen.lib.str; # null: open, valid until always
  };

  yen.fleet.main.today = "2026-11-15";
  yen.environment.prod = { };
  yen.host.web-old = {
    environment = yen.environment.prod;
    validTo = "2026-10-31";
  }; # retired
  yen.host.web = {
    environment = yen.environment.prod;
    validFrom = "2026-10-01";
  };
  yen.host.web-next = {
    environment = yen.environment.prod;
    validFrom = "2026-12-01";
  }; # not yet
  yen.flake = { out, ... }: out;
}
