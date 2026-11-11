#: lib.batteries.docs.starlight-page :: { writers; load; page; files; sidebar; tests; pagesAt; relativeRoot ? ; ending ? ; auto ? ; exempt ? ; } -> { scope; tree; commands ? ; } -> cycle result -- a page's .mdx, sidebar entry and tests
# What the `cycle` of an aspect at a page kind returns, from what the cycle gets (`scope`, `tree`, and a sink the body may
# read). For each page it gives `src/content/docs/<route>.mdx` to the sink `files`, an entry to the sink `sidebar` and its
# checks to the sink `tests`, all refs of sinks. A page that is a repo file too (`alsoAt`) is also written as plain markdown
# there. The page kind is a ref, `page`; its scopes have `title`, `description`, `section`, `order`, `route`, `dir` and `badge`.
# `writers`: `docs.starlight-writers` applied. `load`: a function of a page directory, `{ page; args; }`: `page` is its
# `page.nix` (`body`, and optionally `checks`, `e2e`, `frontmatter`, `alsoAt`, `readmeOnly`, `plainTitle`), `args` what
# its `body` and `checks` receive. The fleet decides how a page is read: the battery reads and evaluates nothing.
# `ending page x writers`: more text at the end of a page, a list. `auto { eq; yes; no; } x`: the checks every page gets.
# Every page also gets `links-resolve`: each internal link in it, `/route/` or `/route/#anchor`, is the route of a page or
# `exempt link`.
#   yen.aspects.page = { at = yen.kinds.page; cycle = { scope, tree, ... }: starlight-page { inherit writers load;
#     page = yen.kinds.page; files = yen.kinds.site.sinks.files; sidebar = yen.kinds.site.sinks.sidebar;
#     tests = yen.kinds.site.sinks.tests; pagesAt = "docs/pages"; } { inherit scope tree; }; };
self:
{
  writers,
  load,
  page,
  files,
  sidebar,
  tests,
  pagesAt,
  relativeRoot ? null,
  ending ?
    _: _: _:
    [ ],
  auto ? _: _: { },
  exempt ? _: false,
}:
{
  scope,
  tree,
  commands ? null,
}:
let
  b = builtins;
  inherit (self._starlight)
    pagesOf
    cmdsOf
    routeOf
    linksIn
    render
    plain
    ;
  cfg = {
    inherit
      writers
      load
      ending
      pagesAt
      relativeRoot
      ;
  };
  eq = expr: expected: { inherit expr expected; }; # a fastest test
  yes = x: eq x true;
  no = x: eq x false;
  when = c: v: if c then v else { };
  x = load scope.dir;
  pageList = pagesOf (tree.select { instances = page; });
  broken = b.filter (l: !b.elem l (map routeOf pageList) && !exempt l) (
    linksIn (render cfg commands pageList scope)
  );
  argsOf = x.args // {
    inherit (writers scope.dir) notesOf;
    inherit eq yes no;
    commands = cmdsOf commands;
    pages = pageList;
  };
  isSite = !(x.page.readmeOnly or false); # a `readmeOnly` page is its repo file only, never a site page
in
{
  tree = [ { instances = page; } ];
  ${files.__sink} = [
    {
      files.file =
        when isSite { "src/content/docs/${scope.route}.mdx".text = render cfg commands pageList scope; }
        // when (x.page ? alsoAt) { ${x.page.alsoAt}.text = plain cfg commands pageList scope; };
    }
  ];
  ${sidebar.__sink} =
    if isSite then
      [
        {
          section = scope.section;
          inherit (scope) order;
          item = {
            label = scope.title;
            slug = scope.route;
          }
          // when (scope.badge != null) { badge = scope.badge; };
        }
      ]
    else
      [ ];
  ${tests.__sink} = [
    {
      ${scope.name} = {
        fast =
          auto { inherit eq yes no; } x
          // {
            links-resolve = eq broken [ ];
          }
          // (x.page.checks or (_: { })) argsOf;
        e2e = (x.page.e2e or (_: { })) argsOf;
      };
    }
  ];
}
