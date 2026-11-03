# Shared pkgs, measured: toplevel drvPaths of `hosts`, each either on the shared pkgs (as the fleet builds them) or
# with its own pkgs (nixosConfigurationsOwnPkgs). A leader has no own-pkgs build: it always builds the shared pkgs.
# Run capped with NIX_SHOW_STATS=1 and compare cpuTime, nrThunks, nrFunctionCalls, values/sets/list bytes, gc.totalBytes:
#   --arg shared true   vs   --arg shared false          (--arg hosts '[ "lb" "web-1" "web-2" ]' for prod)
{
  shared ? true,
  hosts ? [
    "app-1"
    "app-2"
    "app-3"
  ],
}:
let
  o = (import ./query.nix).flake;
  d = c: c.config.system.build.toplevel.drvPath;
  pick =
    n:
    if shared || !(o.nixosConfigurationsOwnPkgs ? ${n}) then
      o.nixosConfigurations.${n}
    else
      o.nixosConfigurationsOwnPkgs.${n};
in
map (n: d (pick n)) hosts
