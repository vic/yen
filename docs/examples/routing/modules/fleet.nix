# fleet > environment > host > user and home. Who receives an element depends on where the sinks are.
{ yen, ... }:
let
  inherit (yen.lib) opt;
in
{
  yen.kinds.fleet = {
    spawns.environment = _: yen.environment;
    sinks.out.reduce = yen.lib.reduce.merge;
    sinks.dns.out =
      { dns, ... }:
      {
        dns.fleet = dns;
      }; # the fallback receiver
  };
  yen.kinds.environment = {
    fields.public = opt yen.lib.bool false;
    spawns.host = yen.lib.pointing "environment" yen.host;
    sinks.dns = {
      at = s: s.public; # a conditional receiver: only public environments
      out =
        { environment, dns, ... }:
        {
          dns.${environment.name} = dns;
        };
    };
  };
  yen.kinds.host = {
    fields.environment = yen.kinds.environment;
    spawns = {
      user = yen.lib.pointing "on" yen.user;
      home = yen.lib.pointing "on" yen.home;
    };
    sinks.os.out =
      { host, os, ... }:
      {
        os.${host.name} = os;
      };
  };
  yen.kinds.user.fields.on = yen.kinds.host;
  yen.kinds.home = {
    fields.on = yen.kinds.host;
    sinks.os.out =
      { home, os, ... }:
      {
        os.${home.name} = os;
      }; # a home builds its own config
  };

  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
}
