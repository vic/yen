{
  # build: nixos-rebuild build --flake .#dev. On the host: sudo nixos-container root-login go
  description = "Claude Code in NixOS containers: each with its own tools and ~/.claude, all sharing one login";

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
  };
}
