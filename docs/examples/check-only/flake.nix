{
  description = "yen: check the model of a fleet you already have";

  # the outputs you have stay as they are (nixosConfigurations, packages, ...); yen adds only its check
  outputs = inputs: {
    inherit
      (inputs.yen.lib.mkFlake {
        inherit inputs;
        inherit (inputs.nixpkgs) lib;
      } (inputs.import-tree ./modules))
      checks
      ;
  };

  inputs = {
    yen.url = "github:vic/yen";
    import-tree.url = "github:denful/import-tree";
    nixpkgs.url = "https://nixos.org/channels/nixos-25.05/nixexprs.tar.xz";
  };
}
