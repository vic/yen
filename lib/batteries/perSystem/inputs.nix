#: lib.batteries.perSystem.inputs :: { inputs; system; } -> { input = { name = value; }; } -- each input's packages and legacyPackages of one system
# The flake inputs read at one system: `(perSystem.inputs { inherit inputs system; }).nixpkgs.hello` is
# `inputs.nixpkgs.packages.<system>.hello`, or `legacyPackages.<system>.hello` when packages has no such name.
#   pkgs' = yen.lib.batteries.perSystem.inputs { inherit inputs; system = scope.name; };
_:
{ inputs, system }:
builtins.mapAttrs (
  _: i:
  if builtins.isAttrs i then
    (i.legacyPackages.${system} or { }) // (i.packages.${system} or { })
  else
    { }
) inputs
