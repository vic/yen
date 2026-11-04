# Behavior: active at every host, gives one NixOS module to the `nixos` sink.
{ yen, ... }:
{
  yen.aspects.base = {
    at = yen.kinds.host; # (1)
    nixos = # (2)
      { host, ... }: # (3)
      {
        networking.hostName = host.name;
        boot.loader.grub.device = "nodev";
        fileSystems."/" = {
          device = "/dev/disk/by-label/nixos";
          fsType = "ext4";
        };
        system.stateVersion = "25.05";
      };
  };

  yen.aspects.motd = {
    at = yen.host.laptop; # (4)
    nixos.environment.etc.motd.text = "managed by yen";
  };
}
