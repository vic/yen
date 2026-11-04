# Den's schema, declared: hosts build NixOS and hold users. Battery parameters are typed fields.
{
  yen,
  inputs,
  ...
}:
let
  inherit (yen.lib) opt maybe;
in
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.host = {
    fields.autologin = maybe yen.kinds.user; # (1) den.batteries.tty-autologin "ana"
    spawns.user = yen.lib.pointing "hosts" yen.user;
    sinks.nixos.out =
      { host, nixos, ... }:
      {
        nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem { modules = nixos; };
      };
  };
  yen.kinds.user.fields = {
    hosts = yen.lib.listOf yen.kinds.host;
    shell = opt (yen.lib.enum [
      "bash"
      "zsh"
      "fish"
    ]) "bash"; # (2) den.batteries.user-shell "fish"
  };

  yen.fleet.main = { };
  yen.flake = { out, ... }: out;

  yen.host.box.autologin = yen.user.ana;
  yen.user.ana = {
    hosts = [ yen.host.box ];
    shell = "fish";
  };
  yen.user.bob.hosts = [ yen.host.box ];
  yen.aspects.box = {
    at = yen.host.box;
    nixos = {
      boot.loader.grub.device = "nodev";
      fileSystems."/" = {
        device = "/dev/sda1";
        fsType = "ext4";
      };
      nixpkgs.hostPlatform = "x86_64-linux";
      system.stateVersion = "25.05";
    };
  };
}
