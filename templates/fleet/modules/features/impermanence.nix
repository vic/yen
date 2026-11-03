# A set collector with a per-host filter (sini cortex-cuda `unpersist`).
{
  yen,
  lib,
  inputs,
  ...
}:
{
  yen.kinds.machine.fields.unpersist = yen.lib.opt (yen.helpers.listOf yen.types.string) [ ];
  yen.host.web-2.unpersist = [ "/var/lib/nginx" ];
  yen.kinds.host.sinks.persist = {
    of = yen.types.string;
    reduce = yen.lib.reduce.set;
    nixos =
      { scope, persist, ... }:
      {
        imports = [ inputs.impermanence.nixosModules.impermanence ];
        environment.persistence."/persist".directories = lib.subtractLists scope.unpersist persist;
      };
  };
}
