# The machines and the people are data. Aspects say where each part of the configuration goes.
{ yen, ... }:
{
  yen.host.server = { };
  yen.mac.studio = { };
  yen.user.alice.hosts = [ yen.host.server ];
  yen.home."alice@work" = {
    user = yen.user.alice;
    system = "x86_64-linux";
  };

  # written once, for NixOS and nix-darwin
  yen.aspects.shared = {
    at = [
      yen.kinds.host
      yen.kinds.mac
    ];
    os =
      { scope, pkgs, ... }:
      {
        networking.hostName = scope.name;
        environment.systemPackages = [ pkgs.git ];
      };
  };
  yen.aspects.server = {
    at = yen.host.server;
    nixos = {
      boot.loader.grub.device = "nodev";
      fileSystems."/" = {
        device = "/dev/sda1";
        fsType = "ext4";
      };
      nixpkgs.hostPlatform = "x86_64-linux";
      system.stateVersion = "25.05";
      users.users.alice.isNormalUser = true;
    };
  };
  yen.aspects.studio = {
    at = yen.mac.studio;
    darwin = {
      nixpkgs.hostPlatform = "aarch64-darwin";
      system.stateVersion = 6;
    };
  };
  # every home-manager configuration: alice on the server, and alice@work without NixOS
  yen.aspects.home-base = {
    at = [
      yen.kinds.user
      yen.kinds.home
    ];
    homeManager.home.stateVersion = "25.05";
  };
  yen.aspects.standalone = {
    at = yen.kinds.home;
    homeManager =
      { home, ... }:
      {
        home.username = home.user.name;
        home.homeDirectory = "/home/${home.user.name}";
      };
  };
}
