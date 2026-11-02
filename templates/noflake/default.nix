# yen: one NixOS host, without flakes
# Pin the sources with npins, niv or fetchTarball.
# Build: nix-build -A nixosConfigurations.laptop.config.system.build.toplevel
{
  yen ? builtins.fetchTarball "https://github.com/vic/yen/archive/main.tar.gz",
  nixpkgs ? builtins.fetchTarball "https://nixos.org/channels/nixos-25.05/nixexprs.tar.xz",
  import-tree ? import (
    builtins.fetchTarball "https://github.com/denful/import-tree/archive/main.tar.gz"
  ),
}:
let
  lib = import "${nixpkgs}/lib";
in
((import yen).lib.eval {
  imports = [ (import-tree ./modules) ];
  # the modules call inputs.nixpkgs.lib.nixosSystem, as with flakes
  inputs.nixpkgs = {
    outPath = nixpkgs;
    lib = lib // {
      nixosSystem = args: import "${nixpkgs}/nixos/lib/eval-config.nix" args;
    };
  };
  inherit lib;
  yen.sinks = {
    inputs = { };
    lib = { };
  };
}).flake
