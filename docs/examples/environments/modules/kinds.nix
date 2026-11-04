# fleet > environment > host > user. Groups are data: an environment grants groups, a user is in groups.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  inherit (yen.lib)
    same
    maybe
    opt
    listOf
    ;
  meets = xs: ys: lib.any (x: lib.any (same x) ys) xs;
in
{
  yen.kinds.fleet = {
    spawns.environment = _: yen.environment;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.group = { }; # (1)
  yen.kinds.environment = {
    fields = {
      domain = yen.lib.str;
      base = maybe yen.kinds.environment; # (2) settings it does not set come from here
      grants = opt (listOf yen.kinds.group) [ ]; # (3)
      settings.timeZone = maybe yen.lib.str;
    };
    spawns.host = yen.lib.pointing "environment" yen.host; # (4)
  };
  yen.kinds.host = {
    fields = {
      environment = yen.kinds.environment;
      settings.timeZone = maybe yen.lib.str;
    };
    spawns.user = s: lib.filterAttrs (_: u: meets u.groups s.environment.grants) yen.user; # (5) access from data
    sinks.nixos.out =
      { host, nixos, ... }:
      {
        nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem { modules = nixos; };
      };
  };
  yen.kinds.user.fields.groups = listOf yen.kinds.group;

  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
}
