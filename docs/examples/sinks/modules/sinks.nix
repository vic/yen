# A sink collects elements and reduces them. `of` checks each element.
{ yen, lib, ... }:
let
  inherit (yen.lib.reduce)
    list
    set
    flat
    one
    merge
    elements
    ;
  sorted = es: {
    value = lib.sort (a: b: a < b) (map (e: e.value) es);
    errors = [ ];
  }; # (1) your own reduce
in
{
  yen.kinds.host.sinks = {
    motd = {
      # (2)
      reduce = list;
      of = yen.lib.str;
    };
    ports = {
      # (3)
      reduce = set;
      of = yen.lib.port;
    };
    packages.reduce = flat; # (4)
    admin.reduce = one; # (5)
    nginx.reduce = merge; # (6)
    owners.reduce = elements; # (7)
    groups.reduce = sorted; # (8)
  };
  # every sink of a host, read as args, to one flake output
  yen.aspects.report = {
    at = yen.kinds.host;
    out =
      {
        host,
        motd,
        ports,
        packages,
        admin,
        nginx,
        owners,
        groups,
        ...
      }:
      {
        ${host.name} = {
          inherit
            motd
            ports
            packages
            admin
            nginx
            groups
            ;
          owners = map (e: e.from.kind) owners;
        };
      };
  };
}
