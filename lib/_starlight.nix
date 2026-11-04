# shared by the starlight batteries (lib/batteries/docs/starlight-*): the pages as data and a page as text. Pure.
# A page is a scope of a kind with `title`, `description`, `section` (a scope with `name` and `order`), `order`, `route`
# and `dir`. `writers` is `docs.starlight-writers` applied, `load` the fleet's loader (a page directory -> { page; args; }).
self:
let
  b = builtins;
  imports = "import { Aside, Badge, Card, CardGrid, FileTree, LinkButton, LinkCard, Steps, TabItem, Tabs } from '@astrojs/starlight/components';";
  # the reduced `commands` sink: each aspect gives a list
  cmdsOf = commands: if commands == null then [ ] else b.concatLists (b.head commands);
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
  # the body of a page: its `body` function gets what `load` gave, the writers, the commands and the other pages
  bodyOf =
    cfg: commands: pageList: page: x:
    x.page.body (
      x.args
      // {
        docs = cfg.writers page.dir;
        commands = cmdsOf commands;
        pages = pageList;
      }
    );
  # the .mdx of a page; x: what `load` gave, d: its writers. `ending` adds text at its end
  mdx =
    cfg: commands: pageList: page: x: d:
    b.concatStringsSep "\n\n" (
      [
        (frontmatter page x d)
        imports
      ]
      ++ bodyOf cfg commands pageList page x
      ++ cfg.ending page x d
    )
    + "\n";
  # a page that is also a plain markdown repo file (CONTRIBUTING.md): its body only, so it must not use MDX components
  plainOf =
    cfg: commands: pageList: page: x:
    b.concatStringsSep "\n\n" (
      [
        "# ${x.page.plainTitle or page.title}"
        "<!-- Generated from ${cfg.pagesAt}/${page.name}/page.nix. Edit there, then run `nix run .#write-files` in ${
          if cfg.relativeRoot == null then "the repository root" else "${cfg.relativeRoot}/"
        }. -->"
      ]
      ++ bodyOf cfg commands pageList page x
    )
    + "\n";
in
{
  inherit cmdsOf;
  routeOf = p: if p.route == "index" then "/" else "/${p.route}/";
  # the internal links of a text: `/route/` or `/route/#anchor`, as `/route/`
  linksIn =
    t:
    b.filter (l: b.substring 0 1 l == "/") (
      b.concatMap (x: if b.isList x then x else [ ]) (b.split ''([]][(]|href=")(/[^)"#]*)'' t)
    );
  # every page as data, in site order: for landing pages and indexes
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
  render =
    cfg: commands: pageList: page:
    mdx cfg commands pageList page (cfg.load page.dir) (cfg.writers page.dir);
  plain =
    cfg: commands: pageList: page:
    plainOf cfg commands pageList page (cfg.load page.dir);
}
