# Den specialisations: a variant scope under a host; its nixos forwards into the host's specialisation.
{ yen, ... }:
{
  yen.kinds.host.spawns.variant = yen.lib.pointing "of" yen.variant;
  yen.kinds.variant = {
    fields.of = yen.kinds.host;
    sinks.nixos.nixos =
      { variant, nixos, ... }:
      {
        specialisation.${variant.name}.configuration.imports = nixos;
      };
  };
  yen.variant.debug.of = yen.host.lb;
  yen.aspects.debug-kernel = {
    at = yen.kinds.variant;
    nixos.boot.kernelParams = [ "debug" ];
  };
}
