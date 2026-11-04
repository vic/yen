# The machines, and one aspect that every one of them gets: it gives the same packages to NixOS, WSL and
# system-manager, each through the key of its own kind.
{ yen, ... }:
let
  tools = pkgs: [
    pkgs.git
    pkgs.htop
  ];
in
{
  yen.host.desk = { };
  yen.wsl.laptop = { };
  yen.machine.vps = { };

  yen.aspects.base = {
    at = [
      yen.kinds.host
      yen.kinds.wsl
    ];
    nixos =
      { scope, ... }:
      {
        networking.hostName = scope.name;
        nixpkgs.hostPlatform = "x86_64-linux";
        system.stateVersion = "25.05";
        fileSystems."/".device = "/dev/disk/by-label/nixos";
        boot.loader.grub.devices = [ "nodev" ];
      };
  };
  yen.aspects.tools = {
    at = [
      yen.kinds.host
      yen.kinds.wsl
      yen.kinds.machine
    ];
    nixos = # (1)
      { pkgs, ... }:
      {
        environment.systemPackages = tools pkgs;
      };
    system = # (2)
      { pkgs, ... }:
      {
        nixpkgs.hostPlatform = "x86_64-linux";
        environment.systemPackages = tools pkgs;
      };
  };
}
