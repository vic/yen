# The fleet writes its own repo files. `flake-file` collects github:denful/flake-file options (flake.nix);
# `files` collects github:sini/files modules (README.md, CI workflow).
{
  yen,
  lib,
  inputs,
  ...
}:
let
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  # flake-file needs `valueMeta` on submodule options: nixos-25.05 lib lacks it
  flakeFileOf =
    flake-file:
    (inputs.nixpkgs-unstable.lib.evalModules {
      specialArgs = { inherit inputs; };
      modules = [
        inputs.flake-file.flakeModules.flake
        { inherit flake-file; }
        { flake-file.formatter = p: p.nixfmt-rfc-style; }
      ];
    }).config.flake-file;
  filesOf =
    files:
    (lib.evalModules {
      modules = [
        inputs.files.module
        {
          _module.args.pkgs = pkgs;
          files.root = inputs.self;
          files.relativeRoot = "docs/examples/generated-files";
        }
      ]
      ++ files;
    }).config.files;
in
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks = {
      out.reduce = yen.lib.reduce.merge;
      flake-file = {
        reduce = yen.lib.reduce.merge; # flake inputs, declared by the aspects that use them
        out =
          { flake-file, ... }:
          {
            packages.x86_64-linux.write-flake = (flakeFileOf flake-file).apps.write-flake pkgs;
            checks.x86_64-linux.flake-file = (flakeFileOf flake-file).check-flake-file pkgs;
          };
      };
      files.out =
        { files, ... }:
        {
          packages.x86_64-linux.write-files = (filesOf files).writer.drv;
          checks.x86_64-linux = (filesOf files).checks; # each committed file must match
        };
    };
  };
  yen.kinds.host.sinks.nixos.out =
    { host, nixos, ... }:
    {
      nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem { modules = nixos; };
    };

  yen.fleet.main = { };
  yen.host.web = { };
  yen.flake = { out, ... }: out;
}
