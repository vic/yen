# Each aspect is one NixOS pattern. None of them knows the files that read it.
{ yen, ... }:
{
  yen.aspects = {
    fw = {
      at = yen.kinds.host;
      firewall = { ports, ... }: builtins.sort builtins.lessThan ports; # (1) reads another option: config.ports
    };
    ssh = {
      at = yen.kinds.host;
      ports = 22;
    };
    web = {
      at = yen.host.a;
      ports = 80;
    };
    tls = {
      at = yen.aspects.web; # (2) mkIf: active where web is
      ports = 443;
    };
    base = {
      at = yen.kinds.host;
      settings.log.level = "info";
      motd = {
        prio = 1000;
        text = "welcome";
      };
    };
    tuned = {
      at = yen.host.b;
      settings.log.file = "/var/log/b";
      motd = {
        prio = 50;
        text = "maintenance";
      };
    };
    addrs = {
      at = yen.kinds.host;
      addrs = # (3) every host gives its address to the fleet
        { host, ... }:
        {
          ${host.name} = host.addr;
        };
      peers = { host, addrs, ... }: removeAttrs addrs [ host.name ]; # (4) the other nodes, through the fleet
    };
  };
}
