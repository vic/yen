# Hosts build NixOS. Users live under their hosts; a user's home-manager content goes into each host.
{
  yen,
  inputs,
  ...
}:
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.host = {
    spawns.user = yen.lib.pointing "hosts" yen.user;
    sinks.nixos.out = # (1)
      { host, nixos, ... }:
      {
        nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem { modules = nixos; };
      };
  };
  yen.kinds.user = {
    fields.hosts = yen.lib.listOf yen.kinds.host;
    sinks.homeManager.nixos = # (2)
      { user, homeManager, ... }:
      {
        home-manager.users.${user.name}.imports = homeManager;
      };
  };

  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
}
