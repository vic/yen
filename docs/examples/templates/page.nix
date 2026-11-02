let
  root = ../../../templates;
  # every directory of templates/ but the showcase fleet: the list cannot go stale
  dirs = builtins.readDir root;
  names = builtins.filter (n: dirs.${n} == "directory" && n != "fleet") (builtins.attrNames dirs);
  has = n: f: builtins.pathExists (root + "/${n}/${f}");
  # a flake template says what it is in its flake.nix; noflake in the first comment of its default.nix
  describe =
    n:
    if has n "flake.nix" then
      (import (root + "/${n}/flake.nix")).description
    else
      builtins.substring 2 200 (
        builtins.head (builtins.split "\n" (builtins.readFile (root + "/${n}/default.nix")))
      );
  start =
    n:
    if has n "flake.nix" then
      "`nix flake init -t github:vic/yen#${n}`"
    else
      "`curl -L https://github.com/vic/yen/archive/main.tar.gz | tar xz --strip-components=2 yen-main/templates/${n}`, then in `${n}/`: `nix-build -A nixosConfigurations.laptop.config.system.build.toplevel`";
  # a template's own flake.nix, with the docs inputs; flake-parts reads self as a flake, not a path
  selfOf = all: n: {
    outPath = root + "/${n}";
    inputs = all;
    outputs = (import (root + "/${n}/flake.nix")).outputs all;
  };
  inputsOf =
    inputs: n: extra:
    inputs // extra // { self = selfOf (inputsOf inputs n extra) n; };
  # every template, evaluated with the docs inputs
  builtOf = inputs: {
    minimal = (inputsOf inputs "minimal" { }).self.outputs;
    noflake = import (root + "/noflake") {
      yen = inputs.yen.outPath;
      nixpkgs = inputs.nixpkgs.outPath;
      inherit (inputs) import-tree;
    };
    flake-parts =
      (inputsOf inputs "flake-parts" { inherit (inputs.terranix.inputs) flake-parts; }).self.outputs;
    multi-platform = (inputsOf inputs "multi-platform" { }).self.outputs;
  };
  laptop = c: c.nixosConfigurations.laptop.config;
  checksOf = eq: t: {
    minimal = eq (laptop t.minimal).networking.hostName "laptop";
    noflake = eq (laptop t.noflake).networking.hostName "laptop";
    # flake-parts changes nothing in the system yen builds
    flake-parts = eq (laptop t.flake-parts).system.build.toplevel.drvPath (laptop t.minimal)
    .system.build.toplevel.drvPath;
    flake-parts-per-system = eq t.flake-parts.formatter.x86_64-linux.name "nixfmt-tree";
    multi-nixos = eq t.multi-platform.nixosConfigurations.server.config.home-manager.users.alice.home.stateVersion "25.05";
    multi-darwin = eq t.multi-platform.darwinConfigurations.studio.config.networking.hostName "studio";
    multi-home = eq t.multi-platform.homeConfigurations."alice@work".config.home.username "alice";
  };
in
{
  title = "Templates";
  description = "Start a new project from a template: one host, without flakes, inside flake-parts, or three platforms.";
  section = "start";
  order = 6;

  body =
    { docs, ... }:
    [
      ''
        These are small projects for you to copy and grow. The examples in these docs show one idea each;
        a template is a whole project. Each one here is evaluated in our CI.
      ''
      (docs.table [ "Template" "What it is" "Start" ] (
        map (n: [
          "`${n}`"
          (describe n)
          (start n)
        ]) names
      ))
      ''
        Not sure which one? Take `minimal`. [Getting started](/start/getting-started/) is the same host with a step-by-step page.
        `templates/fleet` is the showcase fleet. Read it, but do not start from it: its `yen` input is this repository.
      ''
    ];

  checks =
    { eq, ... }:
    {
      # the docs flake lists every template under its own name, and no example has the same name
      listed = eq (builtins.filter (
        n: !(import ../../templates.nix) ? ${n} && has n "flake.nix"
      ) names) [ ];
      names-free = eq (builtins.filter (n: builtins.pathExists (../. + "/${n}")) names) [ ];
      # a new template directory needs its e2e: builtOf has one key per template (keys only, nothing evaluates)
      e2e-every-template = eq (builtins.attrNames (builtOf { })) names;
    };

  e2e = { inputs, eq, ... }: checksOf eq (builtOf inputs);
}
