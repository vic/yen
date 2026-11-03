# A cascade: host, then its environment, then the environment's base. Data queries, no merge.
{ yen, ... }:
let
  # the kernel channel: the host's, else its environment's, else the base environment's
  channelOf =
    host: environment:
    yen.lib.cascade [ "settings" "kernel" "channel" ] [ host environment environment.base ];
  facterOf = host: ../../facter + "/${host.name}.json";
in
{
  yen.aspects.kernel = {
    at = yen.kinds.host;
    nixos =
      {
        host,
        environment,
        pkgs,
        ...
      }:
      {
        boot.kernelPackages =
          if channelOf host environment == "lts" then pkgs.linuxPackages else pkgs.linuxPackages_latest;
      };
  };
  yen.aspects.facter = {
    at = yen.kinds.host;
    nixos =
      { host, lib, ... }:
      lib.optionalAttrs (builtins.pathExists (facterOf host)) {
        hardware.facter.reportPath = facterOf host;
      };
  };
}
