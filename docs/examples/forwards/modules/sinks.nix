# A sink's other keys give elements to other sinks. They run at the receiver, with its args.
{ yen, ... }:
let
  inherit (yen.lib.reduce) merge;
in
{
  yen.kinds.host.sinks = {
    ports.config =
      { ports, ... }:
      {
        firewall.allowedTCPPorts = ports;
      }; # (1) ports feed config
    config = {
      reduce = merge;
      out =
        { host, config, ... }:
        {
          config.${host.name} = config;
        };
    };
  };
  yen.kinds.guest.sinks = {
    ports.config =
      { ports, ... }:
      {
        firewall.allowedTCPPorts = ports;
      }; # (2)
    config = {
      reduce = merge;
      config =
        { guest, config, ... }:
        {
          vms.${guest.name} = config;
        }; # (3) its own name: a forward up, to the host
    };
  };
}
