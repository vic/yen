# The host is data. The aspect is active at every host and gives it one NixOS module.
{ yen, ... }:
{
  yen.host.laptop = { };

  yen.aspects.base = {
    at = yen.kinds.host;
    nixos =
      { host, ... }:
      {
        networking.hostName = host.name;
        nixpkgs.hostPlatform = "x86_64-linux";
        # placeholder: change fileSystems and boot for your hardware (see your hardware-configuration.nix)
        boot.loader.grub.device = "nodev";
        fileSystems."/" = {
          device = "/dev/disk/by-label/nixos";
          fsType = "ext4";
        };
        system.stateVersion = "25.05";
      };
  };
}
