# Three platforms. A host builds NixOS, a mac builds nix-darwin, a home is a standalone home-manager.
# `os` is written once and forwarded to NixOS and nix-darwin. A user's home-manager goes into each host it lives on.
{
  yen,
  inputs,
  ...
}:
{
  yen.kinds.fleet = {
    spawns = {
      host = _: yen.host;
      mac = _: yen.mac;
      home = _: yen.home;
    };
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.host = {
    spawns.user = yen.lib.pointing "hosts" yen.user;
    sinks = {
      os.nixos =
        { os, ... }:
        {
          imports = os;
        };
      nixos.out =
        { host, nixos, ... }:
        {
          nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem { modules = nixos; };
        };
    };
  };
  yen.kinds.mac.sinks = {
    os.darwin =
      { os, ... }:
      {
        imports = os;
      };
    darwin.out =
      { mac, darwin, ... }:
      {
        darwinConfigurations.${mac.name} = inputs.nix-darwin.lib.darwinSystem { modules = darwin; };
      };
  };
  yen.kinds.user = {
    fields.hosts = yen.lib.listOf yen.kinds.host;
    sinks.homeManager.nixos =
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
    sinks.homeManager.out =
      { home, homeManager, ... }:
      {
        homeConfigurations.${home.name} = inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = inputs.nixpkgs.legacyPackages.${home.system};
          modules = homeManager;
        };
      };
  };
  yen.aspects.home-manager = {
    at = yen.lib.has yen.kinds.user;
    nixos = {
      imports = [ inputs.home-manager.nixosModules.home-manager ];
      home-manager.useGlobalPkgs = true;
    };
  };

  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
}
