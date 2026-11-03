{
  # run: nix run .#go (terminal), nix run .#go-gui (neovide). Build every variant: nix build .#web .#writer
  description = "Neovim variants with nvf: one theme and language set each, and a neovide GUI for each";

  outputs =
    inputs:
    inputs.yen.lib.mkFlake {
      inherit inputs;
      inherit (inputs.nixpkgs) lib;
    } (inputs.import-tree ./modules);

  inputs = {
    yen.url = "github:vic/yen";
    import-tree.url = "github:denful/import-tree";
    # nvf tracks nixos-unstable
    nixpkgs.url = "https://nixos.org/channels/nixos-unstable/nixexprs.tar.xz";
    nvf = {
      url = "github:NotAShelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
