# known_hosts and WireGuard peers: every other host, from its fields. No hosts list to keep in sync.
# Other hosts' data comes through a tree request, so each read is an edge `stage` can see.
{ yen, lib, ... }:
let
  all.instances = yen.kinds.host; # (1) a tree request: every host, with its data
  othersOf = tree: scope: lib.filter (h: !yen.lib.same h scope) (tree.select all); # every host but this one
in
{
  yen.aspects.mesh = {
    # (2)
    at = yen.kinds.host;
    cycle =
      { tree, scope, ... }:
      {
        tree = [ all ]; # (3)
        nixos = [
          {
            programs.ssh.knownHosts = lib.listToAttrs (
              map (h: {
                name = h.name;
                value = {
                  hostNames = [ h.name ];
                  publicKey = h.sshKey;
                };
              }) (othersOf tree scope)
            );
            networking.wireguard.interfaces.wg0 = {
              ips = [ "${scope.wgIp}/24" ];
              privateKeyFile = "/var/lib/wireguard/private.key";
              peers = map (h: {
                publicKey = h.wgKey;
                allowedIPs = [ "${h.wgIp}/32" ];
              }) (othersOf tree scope);
            };
          }
        ];
      };
  };
}
