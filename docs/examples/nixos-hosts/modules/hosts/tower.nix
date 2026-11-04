# One file per host: the instance and its own hardware. A new file is a new host.
{ yen, ... }:
{
  yen.host.tower = { }; # (1)
  yen.aspects.tower = {
    at = yen.host.tower; # (2)
    nixos = {
      boot.loader.systemd-boot.enable = true;
      fileSystems."/" = {
        device = "/dev/disk/by-label/nixos";
        fsType = "ext4";
      };
    };
  };
}
