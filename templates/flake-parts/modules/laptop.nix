# The host is data. The aspect is active at every host and gives it one NixOS module.
{ yen, ... }:
{
  yen.host.laptop.system = "x86_64-linux";

  yen.aspects.base = {
    at = yen.kinds.host;
    nixos =
      { host, ... }:
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
}
