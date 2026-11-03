# Per-feature settings: two files declare types at two paths of one field. Cascade with delegation.
{ yen, lib, ... }:
let
  inherit (yen.lib) maybe opt;
  setting = path: h: yen.lib.cascade path ([ h ] ++ h.environment.delegates ++ [ h.environment ]); # local > delegated > parent
  arcMaxOf = setting [
    "settings"
    "zfs"
    "arcMax"
  ];
in
{
  yen.kinds.machine.fields.settings.zfs.arcMax = maybe yen.lib.int;
  yen.kinds.environment.fields.settings.zfs.arcMax = maybe yen.lib.int;
  yen.kinds.environment.fields.delegates = opt (yen.lib.listOf yen.kinds.environment) [ ];
  yen.environment.prod.settings.zfs.arcMax = 4294967296;
  yen.environment.staging.delegates = [ yen.environment.prod ];
  yen.host.web-1.settings.zfs.arcMax = 8589934592;
  yen.aspects.zfs = {
    at = yen.kinds.host;
    nixos =
      { host, ... }:
      {
        boot.kernelParams = lib.optional (
          arcMaxOf host != null
        ) "zfs.zfs_arc_max=${toString (arcMaxOf host)}";
      };
  };
}
