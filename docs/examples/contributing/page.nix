let
  # the reply the issue bot gives to the code blocks in issue/
  replyOf =
    inputs: dir:
    import (inputs.yen + "/docs/issue/eval.nix") {
      inherit (inputs) yen nixpkgs;
      blocks = dir + "/issue";
    };
  # one row per devshell command, by group
  commandRows = lib: commands: commandRowsIn (lib.groupBy (c: c.category) commands);
  commandRowsIn =
    byCategory:
    builtins.concatMap (
      g:
      map (c: [
        "`${c.name}`"
        g
        c.help
      ]) byCategory.${g}
    ) (builtins.attrNames byCategory);
  replySummary = r: {
    inherit (r) modules;
    errors = map (e: { inherit (e) code from; }) r.errors;
  };
in
{
  title = "Contributing";
  description = "Issues with code, pull requests that exercise the docs examples, and every generator and test, in one place.";
  section = "project";
  order = 2;
  alsoAt = "../CONTRIBUTING.md"; # the same text is the repository's CONTRIBUTING.md: plain markdown only on this page

  body =
    {
      docs,
      inputs,
      dir,
      commands,
      lib,
      ...
    }:
    [
      ''
        Thank you for helping! Bug reports, questions, docs fixes, examples and engine changes are all welcome.
        Yen is small, and every page of its docs is a tested example, so a good report or a good example helps everyone after you.

        ## Open an issue: bring code

        An issue must have a Yen [module](/principles/modules/) that shows the problem, and the issue form asks for one. This isn't a formality:
        CI evaluates every `nix` block of the issue as one fleet and comments the answer, often before a person reads it.

        Each block is one module of `modules/`. Declare the [kinds](/model/kinds-fields/) it needs (`lib` is nixpkgs lib). For example:
      ''
      (docs.file "issue/block-1.nix")
      (docs.file "issue/block-2.nix")
      ''
        CI replies with the errors, the scopes, the active aspects and the invariant check:
      ''
      (docs.value (replyOf inputs dir))
      ''
        Here the answer is right in the reply: a [`one` sink](/behavior/sinks/) with two elements is an error, not an override. The evaluation is pure and
        restricted (`--restrict-eval`), so a block can't read files outside its inputs, and it has a time limit.
        You can run the same evaluation before you post, from the repository root, with your blocks in a directory as `block-1.nix`, `block-2.nix`:
      ''
      (docs.sh ''
        nix-instantiate --eval --strict --json --restrict-eval -I yen=. -I nixpkgs=channel:nixos-25.05 -I blocks=./my-issue \
          --expr 'import ./docs/issue/eval.nix { yen = <yen>; nixpkgs = <nixpkgs>; blocks = <blocks>; }'
      '')
      ''
        ## Send a pull request: exercise the examples

        The best pull request changes or adds an example under `docs/examples/`, since an example is a page, a flake template and a test at once.
        See [getting-started](https://github.com/vic/yen/tree/main/docs/examples/getting-started) for a small one, and the [glossary](/reference/glossary/) for the words.

        1. For a bug, add a check to the closest example's `page.nix`, or a `variants/` file that shows the bug. Run `docs-test` and see it fail.
        2. Fix the engine (`default.nix`, `lib/`) or the example. Run `docs-test` again and see it pass.
        3. For a feature, add a page: copy an example directory, edit `page.nix` and `modules/`, and give it `checks`.
        4. Run `docs-write` to regenerate the pages, then `ci` for every stage.

        An engine change also needs a test in its topic's suite (`tests/model.nix`, `behavior.nix`, `query.nix`,
        `agents.nix` or `logic.nix`), and a battery change needs one in `platforms`, `kits`, `vars`, `docs` or `sinks`. Keep the
        engine to Nix builtins: no nixpkgs, no `throw`.

        ## Coding standards

        A fleet author follows the [Style guide](/principles/style/). Code in Yen itself follows it too, plus these rules
        for `lib/` and `tests/`. Some older files in `lib/` still nest `let`, and they move to this form one at a time.

        What works:

        - One `let` per file, at the top. A binding that needs a value is a function of that value.
        - A leaf file is `self: value`. When the file doesn't use `self`, write `_: value`. Read other leaves from `self`.
        - `default.nix` loads every file under `lib/` into one fixpoint, `self`, each at the path of its file. `tests.nix`
          adds every file under `tests/`: a file directly in `tests/` is a suite, and the `_` files (`_shared.nix` for the
          engine suites, `_batteries.nix` for the battery suites) hold the fixtures they share. A new file is loaded with no
          list to edit.
        - `b = builtins;` in the `let`, then `b.map`, `b.filter`. Name each attribute you use.
        - One `#:` line above each API: `#: <where> :: <takes> -> <returns> -- <purpose>`. The [API page](/reference/lib/)
          is read from these lines, and a check fails when an API has none.
        - A private file starts with `_`. The public names are only what `lib/api.nix` lists.
        - An error is a record: `errWith from message { code; fix; }`, with a code the [error page](/reference/errors/) explains.
        - A type, not an `if`: give a field or a sink a type (`check`, or `parse` for a composite), so bad data is an
          error record where it enters, and the code that reads it needs no test.
        - A ref, not a name: compare instances with `yen.lib.same`, and name kinds, sinks and aspects by their refs.
        - Reuse the shared helpers in `lib/_core/` before you write a new one.
        - A test is `eq expr expected` (or `yes`, `no`). Each new check comes with a mutant: change the code, see the
          check fail, change it back. A single test runs in less than a second.

        What to avoid:

        - `throw`, `abort` and `assert` in new code: return an error record or an inert value.
        - A nested `let`, `with`, `rec` and `import`.
        - An `if` that checks data a type could check.
        - A string where a ref belongs.
        - The same list or function in two files: put it in `lib/_core/` once.
        - A commit without `docs-write` and `reference-write` when the docs or the reference fleet changed.

        Write a Yen module (a kit, a template, an example) in one form: its bindings in one top-level `let`, and its
        attributes as simple assignments that use them. A binding that needs a value from an element (a `member`, a
        `scope`) is a function of it, and there's no `let` inside an element. The let bindings refer to each other
        without `rec`, and they keep the details private:

        ```nix
        { yen, lib, ... }:
        let
          serversOf = member: lib.filter (e: yen.lib.same e.assembly member.assembly && e.role == "server");
        in
        {
          yen.kit.borg.aspects.client.nixos =
            { member, exports, ... }:
            { services.borgbackup.jobs.x.repo = (lib.head (serversOf member exports)).value.repo; };
        }
        ```

        The test `style.one-let` holds every kit, template module, docs example module and reference fleet module to one `let`.

        ## Batteries, kits and assemblies

        [Batteries](/batteries/), [kits](/batteries/kits/) and [assemblies](/recipes/assemblies/) are pluggable and composable:
        a fleet plugs each one in, and they work together without knowing about each other. Before you write or change one,
        read how they work, and read at least two of each that are close to yours, both the code and its docs page, not only this list:

        - Batteries: `lib/batteries/github/workflow.nix`, `lib/batteries/devshell/numtide.nix`, `lib/batteries/perSystem/out.nix`
          and `lib/batteries/kits/members.nix`.
        - Kits: `lib/kits/borg.nix`, `lib/kits/dns.nix` and `lib/kits/base.nix`, which adds other kits.
        - Assemblies: `lib/batteries/kits/assemblies.nix`, `lib/batteries/kits/contract.nix` and the [kits example](/batteries/kits/).

        The rules for a battery, which a review checks:

        - A battery is the value of one key of a fleet that exists (`files`, `out`, `nixos`, `cycle`, a `spawns` entry). It's a
          function of refs, like `from = yen.kinds.x.sinks.y`, and it reads a sink with `sinks.''${from.__sink}`.
        - A battery never sets `yen.kinds`, `yen.helpers`, `yen.flake`, `yen.aspects` or any other fleet name, since the fleet declares its
          own kinds, sinks and flake. A kit only adds names under its own name, like `yen.kit.borg`.
        - A battery never evaluates the engine, never reads `flake.nix` or another file of the project, and never needs `import-tree`.
          If it needs something loaded, the fleet gives it a function.
        - A battery never produces a flake or a complete fleet.
        - Code that several batteries share goes in a private file, `lib/_<name>.nix`, like `lib/_roles.nix`.
        - A battery has a `#:` line, a test with a mutant, and a docs page that shows a real use.

        ## Set up

        `nix develop ./docs` from the repository root (or `nix develop` in `docs/`) gives you a devshell with every command below,
        and `menu` lists them. Each command runs from the repository root, whatever your directory.
      ''
      (docs.table [ "Command" "Group" "What it does" ] (commandRows lib commands))
      ''
        ## Generated files

        Don't edit generated files. Edit their source, then run the generator. A check fails when a committed file is stale.

        The site pages (`docs/src/content/docs/**`) and `docs/src/sidebar.json` aren't committed, because `docs-build`
        and `docs-dev` write them from `docs/examples/*/page.nix` first. The table lists the generated files that are
        committed, because GitHub reads them from the repository:
      ''
      (docs.table
        [ "Files" "Source" "Generator" ]
        [
          [
            "`.github/workflows/test.yml`"
            "`docs/modules/ci.nix`"
            "`docs-write`"
          ]
          [
            "`.github/workflows/issue.yml`, `.github/ISSUE_TEMPLATE/*`"
            "`docs/modules/issues.nix`"
            "`docs-write`"
          ]
          [
            "`CONTRIBUTING.md`"
            "`docs/examples/contributing/page.nix`"
            "`docs-write`"
          ]
          [
            "`reference/README.md`, `reference/ci.json`"
            "`reference/modules/docs/`"
            "`reference-write`"
          ]
          [
            "`reference/flake.nix`"
            "the `flake-file` sink of the fleet"
            "`reference-flake`"
          ]
        ]
      )
      ''
        ## Which task to run, and when

        Run the fast tasks while you work, push, and leave the heavy ones to CI. Don't wait for a heavy task on your machine.
        Put `timeout 300` before any command that can run long, because an evaluation that doesn't finish is a finding to report,
        not a reason to wait. Run a slow task in the background and read its output when it ends.

        The fast ones, to run often:
      ''
      (docs.table
        [ "You changed" "Run while you work" ]
        [
          [
            "an example under `docs/examples/`"
            "`docs-example NAME` for that example, then `docs-test`"
          ]
          [
            "the engine (`default.nix`, `lib/`) or a battery"
            "`engine-test`, and the `docs-example` of the page that shows it"
          ]
          [
            "the reference fleet (`reference/`)"
            "`reference-test`"
          ]
          [
            "any Nix file"
            "`fmt`, last"
          ]
        ]
      )
      ''
        Before every push, run the generator of every generated file whose source you changed (see the table above).
        A red CI job that says a file is stale means you didn't run its generator. These two are easy to forget:

        - `docs-write` writes `README.md`, `CONTRIBUTING.md` and the workflows (and the site pages, which aren't committed).
        - `reference-write` writes the reference fleet's README, which lists engine names like the reduce strategies and the
          library functions. An engine change often changes both, so run both.

        The heavy ones, to leave to CI:
      ''
      (docs.table
        [ "Task" "Why it waits for CI" ]
        [
          [
            "`docs-e2e`, `reference-e2e`"
            "real NixOS, nix-darwin and home-manager evaluations"
          ]
          [
            "`engine-cost`, `reference-cost`"
            "cost oracles over whole evaluations"
          ]
          [
            "`reference-check`, `reference-eval`, `docs-check`, `docs-build`"
            "a flake check or a build of every output, or of the site"
          ]
          [
            "`reference-mcp`"
            "builds the Rust server"
          ]
          [
            "`ci`"
            "every stage in one terminal, one after another"
          ]
        ]
      )
      ''
        Fix a failed push with a new commit on the same branch. Don't rewrite pushed history.

        ## CI

        CI runs in stages, one after another, so a push doesn't start every job at once: `fmt`, `engine`, `docs`, `fleet`,
        then `flake-check` and one evaluation job per system. `ci` in the devshell runs the same stages locally, except the last.
        The `aarch64-darwin` evaluation isn't binding (`continue-on-error`), because a darwin runner can take a long time to
        show up, and a merge doesn't wait for it.

        ## Maintenance

        - **Update inputs.** Run `nix flake update` in `docs/` and in `reference/`, then `ci`. nixpkgs comes from the
          nixos.org channel tarballs, not from GitHub.
        - **After a nixpkgs update**, the reference fleet's trimmed module lists belong to the old revision, so `reference-e2e` fails on
          `modlist-same-drv` until they're computed again.
        - **Format** with `fmt`, and CI checks it with `fmt-check`.
        - **A new error code** in the engine fails the docs until the Error codes page (`docs/examples/errors-reference`) explains it.
      ''
    ];

  checks =
    {
      inputs,
      dir,
      eq,
      yes,
      no,
      ...
    }:
    {
      # one issue eval, one comparison
      reply = eq (replySummary (replyOf inputs dir)) {
        modules = 2;
        errors = [
          {
            code = "one";
            from = "fleet:main/host:web";
          }
        ];
      };
    };
}
