# NixOS `config` becomes instance data, and `mkIf` becomes `at`.
{ yen, ... }:
{
  yen.fleet.main = { };
  yen.flake = { }; # (1) no flake outputs: this page reads the eval result
  yen.host = {
    web = {
      addr = "10.0.0.1";
      firewall.enable = true; # (2)
      firewall.ports = [ 443 ];
    };
    db.addr = "10.0.0.2";
  };
  yen.user.ana.on = yen.host.web; # (3)
  yen.aspects.firewall = {
    # (4) mkIf config.firewall.enable. `at` runs at every scope: guard with the kind, then read the field
    at = yen.lib.all [
      yen.kinds.host
      (s: s.firewall.enable)
    ];
    nixos =
      { host, ... }:
      {
        networking.firewall.allowedTCPPorts = host.firewall.ports;
      };
  };
}
