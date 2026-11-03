# The combinators this fleet reuses, named once in `yen.helpers`: any file reads them.
{ yen, ... }:
{
  yen.helpers = {
    # a predicate: a host in prod that has a user
    servesPeople = yen.lib.all [
      # (1)
      (yen.lib.within yen.env.prod)
      (yen.lib.below yen.kinds.user)
    ];
    # a value: the NixOS firewall that opens these ports
    openPorts = ports: { networking.firewall.allowedTCPPorts = ports; }; # (2)
  };
}
