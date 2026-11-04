# Hosts build NixOS and hold their users. Homes are standalone home-manager configurations.
{
  yen,
  inputs,
  ...
}:
{
  yen.kinds.fleet = {
    spawns = {
      host = _: yen.host;
      home = _: yen.home; # (1)
    };
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.host = {
    spawns.user = yen.lib.pointing "hosts" yen.user; # (2)
    sinks.nixos.out =
      { host, nixos, ... }:
      {
        nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem { modules = nixos; };
      };
  };
  yen.kinds.user = {
    fields.hosts = yen.lib.listOf yen.kinds.host;
    sinks.homeManager.nixos = # (3)
      { user, homeManager, ... }:
      {
        home-manager.users.${user.name}.imports = homeManager;
      };
  };
  yen.kinds.home = {
    fields = {
      user = yen.kinds.user;
      system = yen.lib.str;
    };
    sinks.homeManager.out = # (4)
      { home, homeManager, ... }:
      {
        homeConfigurations.${home.name} = inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = inputs.nixpkgs.legacyPackages.${home.system};
          modules = homeManager;
        };
      };
  };
  yen.aspects.home-manager = {
    at = yen.lib.below yen.kinds.user;
    nixos = {
      imports = [ inputs.home-manager.nixosModules.home-manager ];
      home-manager.useGlobalPkgs = true;
    };
  };

  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
}
