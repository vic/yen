{
  description = "yen inside flake-parts";

  # yen gives the `flake` outputs (nixosConfigurations); flake-parts keeps perSystem and its own modules
  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      flake = inputs.yen.lib.mkFlake {
        inherit inputs;
        inherit (inputs.nixpkgs) lib;
      } (inputs.import-tree ./modules);
      perSystem =
        { pkgs, ... }:
        {
          formatter = pkgs.nixfmt-tree;
        };
    };

  inputs = {
    yen.url = "github:vic/yen";
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:denful/import-tree";
    nixpkgs.url = "https://nixos.org/channels/nixos-25.05/nixexprs.tar.xz";
  };
}
