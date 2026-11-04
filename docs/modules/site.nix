# The docs site as a fleet, from the docs battery: one page per directory of examples/. A directory is a flake template
# (flake.nix and modules/ when the page has code) and page.nix, its prose. The docs evaluate the page's own flake.nix
# with the docs inputs, so the page shows what runs. Sections are data.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  repo = "https://github.com/vic/yen";
  site = inputs.yen.lib.batteries.docs.starlight {
    inherit
      yen
      lib
      inputs
      repo
      ;
    pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
    repoRoot = ../..;
    pages = ../examples;
    pagesAt = "docs/examples";
    relativeRoot = "docs";
    engine = inputs.yen.lib; # stage, program, without: functions of a module
    read = import; # the battery loads page.nix and flake.nix with it
    linkExempt = lib.hasPrefix "/yen.png";
    # a link to a file of the fleet in reference/, at a line
    extra = _: {
      fleet =
        path: line: label:
        "[${label}](${repo}/blob/main/reference/${path}${
          lib.optionalString (line != null) "#L${toString line}"
        })";
    };
    runIt =
      page: d:
      d.tip "Run this example" ''
        Every block on this page is a file of the template `${page.name}`. Copy it and run it:

        ${d.sh "nix flake init -t github:vic/yen#${page.name}"}

        ${d.tree}
      '';
    sections = {
      start = {
        title = "Start";
        order = 1;
      };
      migrate = {
        title = "Move to yen";
        order = 2;
      };
      model = {
        title = "Model";
        order = 3;
      };
      behavior = {
        title = "Behavior";
        order = 4;
      };
      principles = {
        title = "Principles";
        order = 5;
      };
      query = {
        title = "Ask and prove";
        order = 6;
      };
      agents = {
        title = "For agents";
        order = 7;
      };
      recipes = {
        title = "Recipes";
        order = 8;
      };
      nixos = {
        title = "NixOS patterns in yen";
        order = 9;
      };
      den = {
        title = "Den patterns in yen";
        order = 10;
      };
      batteries = {
        title = "Battery packs";
        order = 11;
      };
      perf = {
        title = "Performance";
        order = 12;
      };
      reference = {
        title = "Reference";
        order = 13;
      };
      project = {
        title = "Project";
        order = 14;
      };
    };
  };
in
{
  # literal keys, and the battery from `inputs`: the engine reads these before the `yen` arg exists
  yen = {
    inherit (site.yen)
      helpers
      kinds
      section
      page
      site
      flake
      aspects
      ;
  };
}
