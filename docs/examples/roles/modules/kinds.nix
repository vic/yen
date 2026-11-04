# Machines carry facts. No host file names its roles: the facts decide.
{ yen, lib, ... }:
let
  inherit (yen.lib) opt is;
in
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.host.fields = {
    form = yen.lib.enum [
      # (1)
      "server"
      "laptop"
      "desktop"
    ];
    gpu = opt (yen.lib.enum [
      # (2)
      "none"
      "nvidia"
      "amd"
    ]) "none";
    labels = opt (yen.lib.listOf (is builtins.isString)) [ ]; # (3)
  };

  yen.fleet.main = { };
  yen.host.rack-1 = {
    form = "server";
    labels = [ "ci-runner" ]; # (4)
  };
  yen.host.rack-2.form = "server";
  yen.host.thinkpad.form = "laptop";
  yen.host.tower = {
    form = "desktop";
    gpu = "nvidia";
  };
  yen.flake = { out, ... }: out;
}
