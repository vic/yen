let
  # one row per writer: the name a page body calls (`docs.<name>`), and what it gives
  writers = [
    [
      "file"
      "a file of the page, as a titled code block; `fileWith` adds marks, `fileNoted` marks the `# (1)` notes"
    ]
    [
      "repoFile"
      "a file of the repository, titled by its path"
    ]
    [
      "nix"
      "a Nix code block; `code lang text` is the same for any language, `sh` a terminal"
    ]
    [
      "value"
      "a Nix value, printed: what a query answers"
    ]
    [
      "note"
      "an aside; `tip` and `caution` are the same with another type"
    ]
    [
      "tabs"
      "tabs from `[ { label; body; } ]`"
    ]
    [
      "steps"
      "a numbered list of steps"
    ]
    [
      "cards"
      "cards from `[ { title; body; icon ? ; } ]`; `links` makes link cards"
    ]
    [
      "table"
      "a markdown table from the column titles and the rows"
    ]
    [
      "tree"
      "the files of the page directory, as a file tree"
    ]
    [
      "mermaid"
      "a diagram from text; `scopes result` and `routes result` draw an eval result"
    ]
    [
      "src"
      "the repository link of a file of the page, for edit links"
    ]
  ];
  # the writers of a page directory: what a page body calls as `docs.<name>`
  writersOf =
    engine:
    (engine.batteries.docs.starlight-writers {
      lib = null; # only `value` reads it
      repo = "";
      repoRoot = ./.;
      pagesAt = "";
    })
      ./.;
in
{
  title = "Starlight docs battery";
  description = "yen.lib.batteries.docs.starlight: a Starlight docs site as a fleet, one page per directory, with its sidebar, files and tests. These docs use it.";
  section = "batteries";
  route = "batteries/starlight";
  order = 12;

  body =
    { docs, ... }:
    [
      ''
        This documentation site is built by a [battery](/batteries/). `docs.starlight` turns a directory of pages into a
        fleet: one [scope](/model/scopes/) per page, and for each page an `.mdx` file, a sidebar entry and
        tests. It writes [Starlight](https://starlight.astro.build) pages and knows nothing of yen's own docs. These docs call it like this:
      ''
      (docs.repoFile "docs/modules/site.nix")
      ''
        You give `pages`, the directory of pages, and `sections`, the groups of the sidebar. `repo`, `repoRoot` and
        `pagesAt` build the edit and source links. `files` and `root` write the files. `load` reads a page directory: the battery
        does not read page files or evaluate anything, so the fleet decides how (see below). The rest is optional. `ending` adds text
        at the end of a page, `auto` gives every page its checks, `extra` adds writers to the body, and `linkExempt` names an
        internal link that is not a page.

        ## A page is a directory

        Each directory of `pages` is one page. `page.nix` holds its prose and its checks. When the page has code, `modules/` is a
        fleet that the page queries, and `flake.nix` makes the directory a flake template. This is the shape of `page.nix`:
      ''
      (docs.nix ''
        {
          title = "Why";
          description = "One line for the page and the search result.";
          section = "start";   # a key of `sections`
          order = 1;           # the place in its section
          body = { docs, result, ... }: [ "prose" (docs.file "modules/fleet.nix") (docs.value result.errors) ];
          checks = { result, eq, ... }: { errors = eq result.errors [ ]; };
        }
      '')
      ''
        `body` is a list of strings: prose, and the output of the writers. The writers read the page directory, so a
        code block is always a file that runs. `result` is the eval of `modules/`: a value you print is a value the
        fleet computed. `load` gives a page these names. It returns `{ page; args; }`: `page` is the `page.nix`, and `args` is what `body` and
        `checks` receive. The docs fleet above loads a page by evaluating its `modules/` and reading its `flake.nix`; another site
        can load pages in any other way.

        ## The writers

        A page body calls these as `docs.<name>`. `docs.starlight-writers` makes them, and `extra` adds your own:
      ''
      (docs.table [ "Writer" "Gives" ] (
        map (w: [
          "`docs.${builtins.elemAt w 0}`"
          (builtins.elemAt w 1)
        ]) writers
      ))
      ''
        ## What the site gives

        - `src/content/docs/<route>.mdx` for each page, and `src/sidebar.json`. They are a build output: `nix run .#write-files`
          writes them, and no check compares them to a committed file.
        - A page with `alsoAt` is also written as plain markdown at that path, such as `README.md` or
          `CONTRIBUTING.md`. A committed file like this has a check: it must match.
        - `tests.fast.<page>.<check>` and `tests.e2e.<page>.<check>`, for [fastest](https://github.com/denful/fastest).
          Every page gets `no-errors` when it has a fleet, and `inputs-known` and `flake-is-eval` when it is a
          template. `site.links-resolve` fails when an internal link names no page.
      ''
      (docs.caution "Take the battery from inputs" ''
        The engine reads the keys of a module before the `yen` argument exists. Call `inputs.yen.lib.batteries.docs.starlight`, not
        `yen.lib.batteries.docs.starlight`, and give the keys of `yen` by name: `yen = { inherit (site.yen) kinds page; };`.
        Otherwise the eval fails with `its keys read an arg`.
      '')
    ];

  checks =
    { engine, yes, ... }:
    {
      # every writer the table names exists: the table cannot drift from the battery
      writers-exist = yes (builtins.all (r: writersOf engine ? ${builtins.elemAt r 0}) writers);
    };
}
