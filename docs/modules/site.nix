# The docs site as a fleet: one page per directory of examples/. A directory is a flake template (flake.nix and modules/
# when the page has code) and page.nix, its prose. The docs evaluate the page's own flake.nix with the docs inputs, so
# the page shows what runs. The site is the fleet; the markup, the sidebar, the checks and the links are batteries
# (yen.lib.batteries.docs.starlight-*). Sections are data.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  inherit (yen.lib) is;
  inherit (yen.lib.reduce) merge list;
  docs = yen.lib.batteries.docs;
  repo = "https://github.com/vic/yen";
  pagesAt = "docs/examples";
  engine = inputs.yen.lib; # stage, program, without: functions of a module
  site = yen.kinds.site;

  # a page directory as data. The fleet loads it: page.nix, the eval of modules/, and flake.nix as a template
  has = dir: f: builtins.pathExists (dir + "/${f}");
  moduleOf = dir: {
    imports = [ (inputs.import-tree (dir + "/modules")) ];
    inherit inputs;
    inherit (inputs.nixpkgs) lib;
    yen.sinks = {
      inputs = { };
      lib = { };
    };
  };
  flakeNix = dir: import (dir + "/flake.nix");
  # the eval result of every query of the page's fleet
  resultOf = dir: if has dir "modules" then engine.eval (moduleOf dir) else null;
  # the page's flake outputs, from its own flake.nix
  flakeOf =
    dir: if has dir "flake.nix" then (flakeNix dir).outputs (inputs // { self = dir; }) else null;
  # the page with one more file (a `variants/` file, outside `modules/`): what a change does
  variantOf =
    dir: f:
    engine.eval {
      imports = [
        (moduleOf dir)
        (dir + "/${f}")
      ];
    };
  # only some files of the page: an early step of a migration
  onlyOf =
    dir: fs:
    engine.eval {
      imports = map (f: dir + "/${f}") fs;
      inherit (moduleOf dir) inputs lib yen;
    };
  load =
    dir:
    let
      result = resultOf dir;
      flake = flakeOf dir;
    in
    {
      page = import (dir + "/page.nix");
      template = has dir "flake.nix";
      inputsKnown =
        !has dir "flake.nix" || lib.all (n: inputs ? ${n}) (lib.attrNames (flakeNix dir).inputs);
      inherit result flake;
      args = {
        inherit
          dir
          inputs
          engine
          lib
          result
          flake
          ;
        module = moduleOf dir;
        variant = variantOf dir;
        only = onlyOf dir;
      };
    };
  # the checks every page gets: its eval has no errors, its template is a flake that evaluates
  auto =
    { eq, yes, ... }:
    x:
    lib.optionalAttrs (x.result != null) {
      no-errors = if x.page.errors or false then yes true else eq (map (e: e.error) x.result.errors) [ ];
    }
    // lib.optionalAttrs x.template {
      inputs-known = yes x.inputsKnown;
      # `checks` aside: yen-lean comes from the inputs a flake gives mkFlake, and the harness gives every one
      flake-is-eval = eq (lib.attrNames (removeAttrs x.flake [ "checks" ])) (
        lib.attrNames (removeAttrs x.result.flake [ "checks" ])
      );
    };
  # a template page ends with the way to run it
  ending =
    page: x: d:
    lib.optional x.template (
      d.tip "Run this example" ''
        Every block on this page is a file of the template `${page.name}`. Copy it and run it:

        ${d.sh "nix flake init -t github:vic/yen#${page.name}"}

        ${d.tree}
      ''
    );
  writers = docs.starlight-writers {
    inherit lib repo pagesAt;
    repoRoot = ../..;
    # a link to a file of the fleet in reference/, at a line
    extra = _: {
      fleet =
        path: line: label:
        "[${label}](${repo}/blob/main/reference/${path}${
          lib.optionalString (line != null) "#L${toString line}"
        })";
    };
  };
  pageDirs = lib.filterAttrs (_: t: t == "directory") (builtins.readDir ../examples);
in
{
  yen.kinds.section.fields = {
    title = yen.lib.str;
    order = yen.lib.int;
  };
  yen.kinds.page.fields = {
    title = yen.lib.str;
    description = yen.lib.str;
    section = yen.kinds.section;
    order = yen.lib.int;
    dir = is builtins.isPath; # the page directory: a flake template
    badge = yen.lib.maybe yen.lib.str; # a sidebar badge: "new", "advanced"
    route = yen.lib.derive yen.lib.str (self: "${self.section.name}/${self.name}"); # the route
  };
  yen.kinds.site = {
    spawns.page = _: yen.page;
    sinks = {
      out.reduce = merge;
      sidebar = {
        reduce = list;
        of = is (v: v ? section && v ? item);
        files = docs.starlight-sidebar { from = site.sinks.sidebar; };
      };
      # the oracles, for github:denful/fastest: tests.fast.<page>.<check> and tests.e2e.<page>.<check> = { expr; expected; }
      tests = {
        reduce = merge;
        out = docs.starlight-tests { from = site.sinks.tests; };
      };
    };
  };
  yen.site.docs = { };
  yen.flake = { out, ... }: out;

  yen.page = lib.mapAttrs (
    slug: _:
    let
      p = import (../examples + "/${slug}/page.nix");
    in
    {
      inherit (p) title description order;
      section = yen.section.${p.section};
      dir = ../examples + "/${slug}";
    }
    // lib.optionalAttrs (p ? badge) { inherit (p) badge; }
    // lib.optionalAttrs (p ? route) { inherit (p) route; }
  ) pageDirs;

  # a page renders the other pages (its lists, its links), so it is a cycle: a tree request gives every page with its data
  yen.aspects.page = {
    at = yen.kinds.page;
    cycle =
      {
        scope,
        tree,
        commands,
        ...
      }:
      docs.starlight-page {
        inherit
          writers
          load
          pagesAt
          ending
          auto
          ;
        page = yen.kinds.page;
        files = site.sinks.files;
        sidebar = site.sinks.sidebar;
        tests = site.sinks.tests;
        relativeRoot = "docs";
        exempt = lib.hasPrefix "/yen.png";
      } { inherit scope tree commands; };
  };

  yen.section = {
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
}
