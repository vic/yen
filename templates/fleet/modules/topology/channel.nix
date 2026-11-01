# Channels: which nixpkgs and home-manager a machine builds with.
{
  yen,
  lib,
  inputs,
  ...
}:
{
  yen.kinds.channel.fields = {
    nixpkgs = lib.types.raw;
    home-manager = lib.types.raw;
    darwin = yen.lib.opt lib.types.raw null;
  };
  yen.channel.stable = {
    nixpkgs = inputs.nixpkgs-25; # nixos-25.05: the trimmed modlists (web-1, app-2) need it
    home-manager = inputs.home-manager;
    darwin = inputs.nix-darwin;
  };
  yen.channel.unstable = {
    nixpkgs = inputs.nixpkgs; # nixpkgs-unstable: every host not in the modlists
    home-manager = inputs.home-manager-unstable;
  };
}
