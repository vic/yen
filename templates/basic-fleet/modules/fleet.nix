# The words of this fleet. The fleet holds environments; an environment holds the machines that name it: hosts
# (NixOS), macs (nix-darwin) and homes (home-manager alone). A host holds the users that live on it. Each sink
# builds one flake output.
{
  yen,
  inputs,
  ...
}:
let
  b = yen.lib.batteries;
in
{
  yen.kinds.fleet = {
    spawns.env = _: yen.env;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.env = {
    fields.domain = yen.lib.str;
    spawns = {
      host = yen.lib.pointing "env" yen.host;
      mac = yen.lib.pointing "env" yen.mac;
      home = yen.lib.pointing "env" yen.home;
    };
    # the packages of the environment's dev shell: `nix develop .#<env>`
    sinks.devshell.reduce = yen.lib.reduce.flat;
    sinks.devshell.out =
      { env, devshell, ... }:
      {
        devShells.x86_64-linux.${env.name} = inputs.nixpkgs.legacyPackages.x86_64-linux.mkShell {
          packages = devshell;
        };
      };
  };
  yen.kinds.host = {
    fields.env = yen.kinds.env;
    spawns.user = yen.lib.pointing "hosts" yen.user;
    sinks.nixos.out =
      { host, nixos, ... }:
      {
        nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem { modules = nixos; };
      };
  };
  yen.kinds.mac = {
    fields.env = yen.kinds.env;
    sinks.darwin.out =
      { mac, darwin, ... }:
      {
        darwinConfigurations.${mac.name} = inputs.nix-darwin.lib.darwinSystem { modules = darwin; };
      };
  };
  yen.kinds.home = {
    fields = {
      env = yen.kinds.env;
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
  yen.kinds.user = {
    fields.hosts = yen.lib.listOf yen.kinds.host;
    sinks.homeManager.nixos =
      { user, homeManager, ... }:
      {
        home-manager.users.${user.name}.imports = homeManager;
      };
  };

  yen.fleet.main = { };
  # the flake, and one deploy-rs node per NixOS host, reached at its name in the domain of its environment
  yen.flake =
    { out, ... }:
    out
    // b.deploy.deploy-rs {
      configurations = out.nixosConfigurations;
      hostname = _: c: c.config.networking.fqdnOrHostName;
      activate = _: c: inputs.deploy-rs.lib.x86_64-linux.activate.nixos c;
    };
}
