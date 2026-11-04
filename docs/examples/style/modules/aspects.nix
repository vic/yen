# The aspects. One `let` at the top: named bindings, each with a comment when its name is not enough.
# The attributes below only assign them.
{ yen, ... }:
let
  inherit (yen.helpers) servesPeople openPorts; # (1)
  hosts.instances = yen.kinds.host; # (2) a tree request is data: name it once, here
  # the names of the other hosts in the environment of host h, from the answer of the tree request
  peersOf = # (3)
    h: all: map (p: p.name) (builtins.filter (p: !yen.lib.same p h && yen.lib.same p.env h.env) all);
in
{
  yen.aspects.firewall = {
    at = yen.kinds.host;
    nixos = { host, ... }: openPorts host.ports;
  };
  yen.aspects.ssh = {
    at = servesPeople;
    nixos.services.openssh.enable = true;
  };
  yen.aspects.peers = {
    at = yen.kinds.host;
    cycle =
      { tree, scope, ... }:
      {
        tree = [ hosts ];
        nixos = [ { networking.hosts."10.0.0.1" = peersOf scope (tree.select hosts); } ]; # (4)
      };
  };
}
