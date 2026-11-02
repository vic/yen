#: lib.kits.facter :: module -- kit facter: the machine's nixos-facter report, read from the directory the assembly sets
# The setting `dir` (a path) holds `<machine>.json`, one report per machine. The member imports it with
# `nixos.facter`; `module` (the facter NixOS module) is set when your nixpkgs has none.
# A machine without a report gets no facter config: the aspect applies only where `<machine>.json` exists (as main's kernel.nix).
#   imports = [ inputs.yen.lib.kits.facter ];
_:
{ yen, lib, ... }:
{
  yen.kit.facter.roles.default.interface.dir.type = lib.types.path;
  yen.aspects.kit-facter = {
    at = yen.lib.all [
      yen.kinds.member
      (s: yen.lib.same (s.kit or null) yen.kit.facter)
      (s: builtins.pathExists (s.settings.dir + "/${s.parent.name}.json"))
    ];
    nixos =
      { member, scope, ... }@args:
      yen.lib.batteries.nixos.facter {
        report = _: member.settings.dir + "/${scope.parent.name}.json";
      } args;
  };
}
