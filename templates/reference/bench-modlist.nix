# Trimmed vs full NixOS base module lists: the toplevel drvPaths of `hosts`, built with the trimmed list (as the fleet
# builds them) or the full one (nixosConfigurationsFull). Measure with NIX_SHOW_STATS: --arg trimmed true / false.
{
  trimmed ? true,
  hosts ? [
    "web-1"
    "app-2"
  ],
}:
let
  o = (import ./query.nix).flake;
  d = c: c.config.system.build.toplevel.drvPath;
in
map (n: d (if trimmed then o.nixosConfigurations.${n} else o.nixosConfigurationsFull.${n})) hosts
