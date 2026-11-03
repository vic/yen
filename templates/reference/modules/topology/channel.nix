# Channels: which nixpkgs and home-manager a machine builds with.
{
  yen,
  lib,
  inputs,
  ...
}:
{
  yen.kinds.channel.fields = {
    nixpkgs = yen.lib.any;
    home-manager = yen.lib.any;
    darwin = yen.lib.opt yen.lib.any null;
  };
  yen.channel.stable = {
    nixpkgs = inputs.nixpkgs-25; # nixos-25.05: the trimmed modlists (web-1, app-2) need it
    home-manager = inputs.home-manager;
    darwin = inputs.nix-darwin;
  };
  yen.channel.unstable = {
    darwin = inputs.nix-darwin-unstable;
    nixpkgs = inputs.nixpkgs; # nixpkgs-unstable: every host not in the modlists
    home-manager = inputs.home-manager-unstable;
  };
}
