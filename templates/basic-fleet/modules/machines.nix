# The environments, the machines and the people are data. Aspects say where each part of the configuration goes.
{ yen, inputs, ... }:
{
  yen.env = {
    prod.domain = "prod.example.org";
    dev.domain = "dev.example.org";
  };
  yen.host = {
    web.env = yen.env.prod;
    lab.env = yen.env.dev;
  };
  yen.mac.studio.env = yen.env.dev;
  yen.home."alice@laptop" = {
    env = yen.env.dev;
    user = yen.user.alice;
    system = "x86_64-linux";
  };
  yen.user.alice.hosts = [
    yen.host.web
    yen.host.lab
  ];

  # every NixOS host: its name in the domain of its environment
  yen.aspects.host = {
    at = yen.kinds.host;
    nixos =
      { host, ... }:
      {
        networking.hostName = host.name;
        networking.domain = host.env.domain;
        nixpkgs.hostPlatform = "x86_64-linux";
        # placeholder: change fileSystems and boot for your hardware
        boot.loader.grub.device = "nodev";
        fileSystems."/" = {
          device = "/dev/disk/by-label/nixos";
          fsType = "ext4";
        };
        system.stateVersion = "25.05";
      };
  };
  # a host with users gets home-manager, and each user an account
  yen.aspects.users = {
    at = yen.lib.has yen.kinds.user;
    nixos = {
      imports = [ inputs.home-manager.nixosModules.home-manager ];
      home-manager.useGlobalPkgs = true;
    };
  };
  yen.aspects.account = {
    at = yen.kinds.user;
    nixos =
      { user, ... }:
      {
        users.users.${user.name}.isNormalUser = true;
      };
  };
  yen.aspects.mac = {
    at = yen.kinds.mac;
    darwin =
      { mac, ... }:
      {
        networking.hostName = mac.name;
        nixpkgs.hostPlatform = "aarch64-darwin";
        system.stateVersion = 6;
      };
  };
  # every home-manager configuration: alice on her hosts, and alice@laptop without NixOS
  yen.aspects.home = {
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
  # the dev shell of every environment: what you need to work on the fleet
  yen.aspects.devshell = {
    at = yen.kinds.env;
    devshell = [
      inputs.nixpkgs.legacyPackages.x86_64-linux.git
      inputs.deploy-rs.packages.x86_64-linux.default
    ];
  };
}
