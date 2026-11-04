# Kinds are your nouns. `spawns` builds the tree from data. Sinks collect what aspects give.
{
  yen,
  inputs,
  ...
}:
let
  inherit (yen.lib) maybe;
in
{
  yen.kinds.fleet.spawns.env = _: yen.env; # (1)
  yen.kinds.fleet.sinks.out.reduce = yen.lib.reduce.merge;
  yen.kinds.env.fields.domain = yen.lib.str;
  yen.kinds.env.spawns.host = yen.lib.pointing "env" yen.host; # (2)
  yen.kinds.host.fields = {
    env = yen.kinds.env;
    db = maybe yen.kinds.host;
  };
  yen.kinds.host.spawns.user = yen.lib.pointing "on" yen.user;
  yen.kinds.host.sinks.os.nixos = # (3)
    { os, ... }:
    {
      imports = os;
    }; # os feeds nixos
  yen.kinds.host.sinks.nixos.out = # (4)
    { host, nixos, ... }:
    {
      nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem { modules = nixos; };
    };
  yen.kinds.user.fields.on = yen.lib.listOf yen.kinds.host;
  yen.flake = { out, ... }: out;
}
