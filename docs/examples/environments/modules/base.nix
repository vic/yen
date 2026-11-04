# Settings cascade: the host, then its environment, then the environment's base.
{ yen, ... }:
let
  setting =
    path: host:
    yen.lib.cascade path [
      # (1)
      host
      host.environment
      (host.environment.base or null)
    ];
in
{
  yen.aspects.base = {
    at = yen.kinds.host;
    nixos =
      { host, environment, ... }:
      {
        networking = {
          hostName = host.name;
          domain = environment.domain;
        };
        time.timeZone = setting [ "settings" "timeZone" ] host; # (2)
        boot.loader.grub.device = "nodev";
        fileSystems."/" = {
          device = "/dev/sda1";
          fsType = "ext4";
        };
        nixpkgs.hostPlatform = "x86_64-linux";
        system.stateVersion = "25.05";
      };
  };
  yen.aspects.time-zones = {
    at = yen.kinds.host;
    out = # (3)
      { host, ... }:
      {
        timeZones.${host.name} = setting [ "settings" "timeZone" ] host;
      }; # goes up to the fleet
  };
  yen.aspects.account = {
    at = yen.kinds.user; # (4)
    nixos =
      { user, ... }:
      {
        users.users.${user.name}.isNormalUser = true;
      };
  };
}
