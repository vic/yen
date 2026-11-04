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
        This documentation site is built from [batteries](/batteries/). They write [Starlight](https://starlight.astro.build)
        pages and know nothing of yen's own docs. Like any battery, each is the value of one key of your fleet, and you keep the
        words: the fleet declares its `page`, `section` and `site` [kinds](/model/kinds-fields/), one [scope](/model/scopes/)
        for each page, and its sinks. These docs do it like this:
      ''
      (docs.repoFile "docs/modules/site.nix")
      ''
        | Battery | Is the value of | Gives |
        |---|---|---|
        | `docs.starlight-page { … }` | what the `cycle` of an aspect at the page kind returns | the `.mdx` of the page to a files sink, its entry to a sidebar sink, its checks to a tests sink, with `links-resolve`: an internal link must name a page |
        | `docs.starlight-sidebar { from; }` | `files` of the sidebar sink | `src/sidebar.json` |
        | `docs.starlight-tests { from; }` | `out` of the tests sink | the flake output `tests.fast.<page>.<check>` and `tests.e2e.<page>.<check>`, for [fastest](https://github.com/denful/fastest) |
        | `docs.starlight-writers { … }` | a function, for the page body | the writers `docs.<name>` below |

        The sinks and the kinds are refs, as in every battery. The battery reads no page file and evaluates nothing: it takes
        `load`, a function of a page directory that returns `{ page; args; }`. `page` is the `page.nix`, and `args` is what its
        `body` and `checks` receive. The docs fleet above loads a page by evaluating its `modules/` and reading its `flake.nix`;
        another site can load pages in any other way. `ending` adds text at the end of a page, and `auto` gives every page its checks.

        ## A page is a directory

        In these docs, each directory of `examples/` is one page. `page.nix` holds its prose and its checks. When the page has code, `modules/` is a
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
        fleet computed.

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
          template. `links-resolve` fails when an internal link names no page.
      ''
    ];

  checks =
    { engine, yes, ... }:
    {
      # every writer the table names exists: the table cannot drift from the battery
      writers-exist = yes (builtins.all (r: writersOf engine ? ${builtins.elemAt r 0}) writers);
    };
}
