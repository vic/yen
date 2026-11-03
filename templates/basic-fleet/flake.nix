{
  # build: nixos-rebuild build --flake .#web, darwin-rebuild build --flake .#studio,
  # home-manager build --flake .#alice@laptop. Deploy: nix run github:serokell/deploy-rs -- .#web
  # Dev shell: nix develop .#prod
  description = "A fleet: environments, their hosts, macs and homes, users, dev shells, deploy-rs";

  outputs =
    inputs:
    inputs.yen.lib.mkFlake {
      inherit inputs;
      inherit (inputs.nixpkgs) lib;
    } (inputs.import-tree ./modules);

  inputs = {
    yen.url = "github:vic/yen";
    import-tree.url = "github:denful/import-tree";
    nixpkgs.url = "https://nixos.org/channels/nixos-25.05/nixexprs.tar.xz";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
