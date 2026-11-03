{
  description = "yen: NixOS, WSL and system-manager machines that share their configuration";

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
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    system-manager.url = "github:numtide/system-manager";
  };
}
