#: lib.batteries.docs.starlight :: { yen; lib; inputs; pkgs; repo; repoRoot; pages; pagesAt; sections; engine; read; ... } -> module -- a Starlight docs site as a fleet: one page per directory of `pages`
# A module for the docs fleet. Each directory of `pages` is a page (docs.pages): `page.nix` (title, description, section,
# order, body and checks) and, when the page has code, `modules/` and `flake.nix`. The site spawns one scope per page.
# A page gives its `.mdx`, its sidebar entry and its tests; the site reduces them to `src/sidebar.json`,
# `packages.write-files` and `tests.{fast,e2e}.<page>.<check>` (github:denful/fastest).
#   `sections`: `{ <name> = { title; order; }; }`, the sidebar groups; `engine`: what a page's `eval` comes from;
#   `read`: loads a Nix file (`import`); `inputs`: needs `nixpkgs`, `import-tree`, `files`, `self`;
#   `extra`: more body writers (docs.starlight-writers); `runIt page writers`: the aside a template page ends with;
#   `linkExempt path`: an internal link that is not a page.
# The engine reads a module's keys before the `yen` arg exists: take the battery from `inputs.yen.lib`, and give the
# module's `yen` keys by name: `yen = { inherit (site.yen) kinds page; };`.
#   site = inputs.yen.lib.batteries.docs.starlight { inherit yen lib inputs pkgs; read = import; repo = "https://github.com/me/proj";
#     repoRoot = ../..; pages = ./pages; pagesAt = "docs/pages"; sections = { start = { title = "Start"; order = 1; }; };
#     engine = inputs.yen.lib; };
self:
{
  yen,
  lib,
  inputs,
  pkgs,
  repo,
  repoRoot,
  pages,
  pagesAt,
  sections,
  engine,
  read,
  relativeRoot ? null,
  extra ? _: { },
  runIt ? null,
  linkExempt ? _: false,
}:
let
  b = builtins;
  inherit (self._core.helpers) genAttrs uniq;
  inherit (yen.lib) is;
  inherit (yen.lib.reduce) merge list;
  writers = self.batteries.docs.starlight-writers {
    inherit
      lib
      repo
      repoRoot
      pagesAt
      extra
      ;
  };
  load = self.batteries.docs.pages { inherit inputs engine read; };

  dirs = b.readDir pages;
  slugs = b.filter (n: dirs.${n} == "directory") (b.attrNames dirs);
  when = c: v: if c then v else { };
  byOrder = p: q: p.order < q.order;
  # a `readmeOnly` page is its repo file only (the README), never a site page
  isSite = x: !(x.page.readmeOnly or false);
  cmdsOf = commands: b.concatLists (b.head commands); # the reduced `commands` sink: each aspect gives a list
  routeOf = p: if p.route == "index" then "/" else "/${p.route}/";

  # a fastest test: { expr; expected; }
  eq = expr: expected: { inherit expr expected; };
  yes = x: eq x true;
  no = x: eq x false;

  # every page as data, in site order: for landing pages and indexes. Tree requests give the instances with their data.
  allPages.instances = yen.kinds.page; # a tree request: every page, with its data
  allSections.instances = yen.kinds.section; # a tree request: every section, with its data
  pagesOf =
    instances:
    map
      (p: {
        inherit (p)
          name
          title
          description
          route
          order
          ;
        section = p.section.name;
      })
      (
        b.sort (
          p: q:
          if p.section.order == q.section.order then p.order < q.order else p.section.order < q.section.order
        ) instances
      );

  imports = "import { Aside, Badge, Card, CardGrid, FileTree, LinkButton, LinkCard, Steps, TabItem, Tabs } from '@astrojs/starlight/components';";
  frontmatter =
    page: x: d:
    "---\n${
      b.toJSON (
        {
          inherit (page) title description;
          editUrl = d.src "page.nix";
        }
        // (x.page.frontmatter or { })
      )
    }\n---";
  # x: the page as data (docs.pages), d: its writers
  bodyWith =
    commands: pageList: page: x:
    x.page.body {
      docs = writers page.dir;
      inherit (x)
        result
        flake
        variant
        only
        dir
        inputs
        module
        engine
        ;
      inherit lib commands;
      pages = pageList;
    };
  renderWith =
    commands: pageList: page: x: d:
    b.concatStringsSep "\n\n" (
      [
        (frontmatter page x d)
        imports
      ]
      ++ bodyWith commands pageList page x
      ++ (if x.template && runIt != null then [ (runIt page d) ] else [ ])
    )
    + "\n";
  # a page can also be a plain markdown repo file (CONTRIBUTING.md): its body only, so it must not use MDX components
  plainWith =
    commands: pageList: page: x:
    b.concatStringsSep "\n\n" (
      [
        "# ${x.page.plainTitle or page.title}"
        "<!-- Generated from ${pagesAt}/${page.name}/page.nix. Edit there, then run `nix run .#write-files` in ${
          if relativeRoot == null then "the repository root" else "${relativeRoot}/"
        }. -->"
      ]
      ++ bodyWith commands pageList page x
    )
    + "\n";
  renderOf =
    commands: pageList: page:
    renderWith commands pageList page (load page.dir) (writers page.dir);

  argsOf = commands: pageList: page: x: {
    inherit (x)
      result
      flake
      variant
      only
      dir
      inputs
      module
      engine
      ;
    inherit (writers page.dir) notesOf;
    inherit
      lib
      commands
      eq
      yes
      no
      ;
    pages = pageList;
  };
  # the checks every page gets: its eval has no errors, its template is a flake that evaluates
  autoOf =
    x:
    when (x.result != null) {
      no-errors = if x.page.errors or false then yes true else eq (map (e: e.error) x.result.errors) [ ];
    }
    // when x.template {
      inputs-known = yes x.inputsKnown;
      # `checks` aside: yen-lean comes from the inputs a flake gives mkFlake, and the harness gives every one
      flake-is-eval = eq (b.attrNames (removeAttrs x.flake [ "checks" ])) (
        b.attrNames (removeAttrs x.result.flake [ "checks" ])
      );
    };
  testsWith = commands: pageList: page: x: {
    fast = autoOf x // (x.page.checks or (_: { })) (argsOf commands pageList page x);
    e2e = (x.page.e2e or (_: { })) (argsOf commands pageList page x);
  };

  # what one page gives: its files, its sidebar entry, its tests
  pageUnit = page: pageList: cmds: x: d: {
    tree = [ allPages ];
    files = [
      {
        files.file =
          when (isSite x) { "src/content/docs/${page.route}.mdx".text = renderWith cmds pageList page x d; }
          // when (x.page ? alsoAt) { ${x.page.alsoAt}.text = plainWith cmds pageList page x; };
      }
    ];
    sidebar = if isSite x then [ (sidebarEntry page) ] else [ ];
    tests = [ { ${page.name} = testsWith cmds pageList page x; } ];
  };
  sidebarEntry = page: {
    section = page.section;
    inherit (page) order;
    item = {
      label = page.title;
      slug = page.route;
    }
    // when (page.badge != null) { badge = page.badge; };
  };

  # every internal link of every page resolves to a page: `/route/` or `/route/#anchor`
  linksIn =
    t: b.concatMap (x: if b.isList x then x else [ ]) (b.split ''([]][(]|href=")(/[^)"#]*)'' t);
  linksOfPages =
    commands: pageList: instances:
    uniq (
      b.filter (l: b.substring 0 1 l == "/") (
        b.concatMap (p: linksIn (renderOf commands pageList p)) instances
      )
    );
  brokenIn = routes: found: b.filter (l: !b.elem l routes && !linkExempt l) found;
  linksUnit = broken: {
    tree = [ allPages ];
    tests = [
      {
        site = {
          fast.links-resolve = eq broken [ ];
          e2e = { };
          inherit broken;
        };
      }
    ];
  };
  linksFor =
    instances: pageList: commands:
    linksUnit (brokenIn (map routeOf pageList) (linksOfPages commands pageList instances));

  # the sidebar: sections in order, pages in order; the home page (path "index") is the splash, not in the sidebar
  sidebarJson =
    by: sectionList:
    b.toJSON (
      map (s: {
        label = s.title;
        items = map (e: e.item) (b.sort byOrder by.${s.name});
      }) (b.sort byOrder (b.filter (s: by ? ${s.name}) sectionList))
    )
    + "\n";
  sidebarUnit = entries: sectionList: {
    tree = [ allSections ];
    files = [
      {
        files.file."src/sidebar.json".text = sidebarJson (b.groupBy (e: e.section.name) (
          b.filter (e: e.item.slug != "index") entries
        )) sectionList;
      }
    ];
  };

  linksOf = instances: commands: linksFor instances (pagesOf instances) commands;

  pageMeta = slug: read (pages + "/${slug}/page.nix");
  pageOf =
    slug: p:
    {
      inherit (p) title description order;
      section = yen.section.${p.section};
      dir = pages + "/${slug}";
    }
    // when (p ? badge) { inherit (p) badge; }
    // when (p ? route) { inherit (p) route; };
in
{
  yen.helpers.docs = writers;
  yen.helpers.pages = load;

  yen.kinds.section.fields = {
    title = yen.lib.str;
    order = yen.lib.int;
  };
  yen.kinds.page.fields = {
    title = yen.lib.str;
    description = yen.lib.str;
    section = yen.kinds.section;
    order = yen.lib.int;
    dir = is b.isPath; # the page directory: a flake template
    badge = yen.lib.maybe yen.lib.str; # a sidebar badge: "new", "advanced"
    route = yen.lib.derive yen.lib.str (s: "${s.section.name}/${s.name}"); # the route
  };
  yen.kinds.site = {
    spawns.page = _: yen.page;
    sinks = {
      out.reduce = merge;
      sidebar = {
        reduce = list;
        of = is (v: v ? section && v ? item);
      };
      # the oracles, for github:denful/fastest: tests.fast.<page>.<check> and tests.e2e.<page>.<check> = { expr; expected; }
      tests = {
        reduce = merge;
        out =
          { tests, ... }:
          {
            tests = genAttrs [ "fast" "e2e" ] (k: b.mapAttrs (_: t: t.${k}) tests);
          };
      };
      # the site pages and sidebar are a build output, not a source: written, never committed, so they get no check
      files.out = yen.lib.batteries.files.writer {
        from = yen.kinds.site.sinks.files;
        inherit (inputs) files;
        inherit lib pkgs relativeRoot;
        root = inputs.self;
        unchecked = p: b.substring 0 17 p == "src/content/docs/" || p == "src/sidebar.json";
      };
    };
  };
  yen.site.docs = { };
  yen.flake = { out, ... }: out;
  yen.section = sections;
  yen.page = genAttrs slugs (slug: pageOf slug (pageMeta slug));

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
      pageUnit scope (pagesOf (tree.select allPages)) (cmdsOf commands) (load scope.dir) (
        writers scope.dir
      );
  };
  yen.aspects.links = {
    at = yen.kinds.site;
    cycle = { tree, commands, ... }: linksOf (tree.select allPages) (cmdsOf commands);
  };
  yen.aspects.sidebar = {
    at = yen.kinds.site;
    cycle = { sidebar, tree, ... }: sidebarUnit (b.head sidebar) (tree.select allSections);
  };
}
