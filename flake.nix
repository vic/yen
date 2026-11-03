{
  outputs =
    _:
    let
      yen = import ./.;
      inherit (yen.lib.batteries.lean) systems;
      # no flake input: the tools build from the nixpkgs docs/flake.lock pins, fetched only when a tool is used
      nixpkgs = builtins.fetchTree (builtins.fromJSON (builtins.readFile ./docs/flake.lock))
        .nodes.nixpkgs.locked;
      tools =
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          yen-cert-check = pkgs.callPackage ./lean/package.nix { };
          yen-mcp = pkgs.callPackage ./mcp/package.nix { };
        };
      perSystem =
        f:
        builtins.listToAttrs (
          map (system: {
            name = system;
            value = f (tools system);
          }) systems
        );
    in
    {
      inherit (yen) lib;
      templates = import ./docs/templates.nix;
      # the engine suites, for github:denful/fastest: nix run github:denful/fastest#fastest -- --flake .#tests
      tests = import ./tests.nix;
      # nix run github:vic/yen#yen-cert-check -- verdict.json, nix run github:vic/yen#yen-mcp
      packages = perSystem (t: t);
      apps = perSystem (
        builtins.mapAttrs (
          name: pkg: {
            type = "app";
            program = "${pkg}/bin/${name}";
            inherit (pkg) meta;
          }
        )
      );
    };
}
