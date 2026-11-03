# Contributing

<!-- Generated from docs/examples/contributing/page.nix. Edit there, then run `nix run .#write-files` in docs/. -->

Thank you for helping. Bug reports, questions, docs fixes, examples and engine changes are all welcome.
yen is small, and every page of its docs is a tested example, so a good report or a good example helps everyone after you.

## Open an issue: bring code

An issue must have a yen [module](/principles/modules/) that shows the problem. The issue form asks for one. This is not a formality:
CI evaluates every `nix` block of the issue as one fleet and comments the answer, often before a person reads it.

Each block is one module of `modules/`. Declare the [kinds](/model/kinds-fields/) it needs; `lib` is nixpkgs lib. For example:


```nix title="issue/block-1.nix"
# The fleet: a root kind, and a host kind with an `admin` sink that takes one element.
{ yen, ... }:
{
  yen.kinds.fleet.spawns.host = _: yen.host;
  yen.kinds.host.sinks.admin.reduce = yen.lib.reduce.one;
  yen.fleet.main = { };
  yen.host.web = { };
}
```

```nix title="issue/block-2.nix"
# The problem: two aspects give an admin. I expected the second to win.
{ yen, ... }:
{
  yen.aspects.ops = {
    at = yen.kinds.host;
    admin = "ana";
  };
  yen.aspects.dev = {
    at = yen.host.web;
    admin = "bo";
  };
}
```

CI replies with the errors, the scopes, the active aspects and the invariant check:


```nix title="result"
{
  active = {
    dev = [
      "fleet:main/host:web"
    ];
    ops = [
      "fleet:main/host:web"
    ];
  };
  check = {
    incomplete = [ ];
    ok = true;
    violations = [ ];
  };
  errors = [
    {
      class = "fixable";
      code = "one";
      error = "one: got 2 elements";
      from = "fleet:main/host:web";
      got = 2;
      path = [ ];
      sink = "admin";
      want = 1;
    }
  ];
  modules = 2;
  scopes = [
    "fleet:main"
    "fleet:main/host:web"
  ];
  undefined = [ ];
}
```

Here the answer is in the reply: a `one` sink with two elements is an error, not an override. The evaluation is pure and
restricted (`--restrict-eval`): a block cannot read files outside its inputs, and it has a time limit.
Run the same evaluation before you post, from the repository root, with your blocks in a directory as `block-1.nix`, `block-2.nix`:


```sh frame="terminal"
nix-instantiate --eval --strict --json --restrict-eval -I yen=. -I nixpkgs=channel:nixos-25.05 -I blocks=./my-issue \
  --expr 'import ./docs/issue/eval.nix { yen = <yen>; nixpkgs = <nixpkgs>; blocks = <blocks>; }'
```

## Send a pull request: exercise the examples

The best pull request changes or adds an example under `docs/examples/`. An example is a page, a flake template and a test at once.

1. For a bug, add a check to the `page.nix` of the closest example, or a `variants/` file that shows the bug. Run `docs-test`: it fails.
2. Fix the engine (`default.nix`, `lib/`) or the example. Run `docs-test` again: it passes.
3. For a feature, add a page: copy an example directory, edit `page.nix` and `modules/`, and give it `checks`.
4. Run `docs-write` to regenerate the pages, then `ci` for every stage.

A change to the engine also needs a test in the suite of its topic: `tests/model.nix`, `behavior.nix`, `query.nix`,
`agents.nix` or `logic.nix`; a battery change, in `platforms`, `kits`, `vars`, `docs` or `sinks`. Keep the engine to Nix
builtins: no nixpkgs, no `throw`.

## Coding standards

A fleet author follows the [Style guide](/principles/style/). Code in yen itself follows it too, with these rules
for `lib/` and `tests/`. Some older files in `lib/` still nest `let`; they move to this form one at a time.

What works:

- One `let` per file, at the top. A binding that needs a value is a function of that value.
- A leaf file is `self: value`. If the file does not use `self`, write `_: value`. Read other leaves from `self`.
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

Write a Yen module (a kit, a template, an example) in one form: its bindings in one top-level `let`, its
attributes simple assignments that use them. A binding that needs a value of an element (a `member`, a
`scope`) is a function of it; there is no `let` inside an element. The let bindings refer to each other
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

## Set up

`nix develop ./docs` from the repository root (or `nix develop` in `docs/`) gives a devshell with every command below.
`menu` lists them. Each command runs from the repository root, whatever your directory.


| Command | Group | What it does |
|---|---|---|
| `ci` | ci | run the CI stages locally, in order: fmt, engine, docs, fleet (reference-check and the per-arch evals not included) |
| `test-all` | ci | every *-test command: engine, docs, fleet (no e2e, no cost) |
| `fastest-all` | ci | every fastest suite at once, in parallel: engine, docs fast and e2e, fleet and e2e (FASTEST_WORKERS each, default 4) |
| `check-all` | ci | every *-check command: fmt, docs, fleet |
| `docs-write` | docs | write the pages and the sidebar from examples/ |
| `docs-test` | docs | the checks of every example (fast) |
| `docs-example` | docs | the fast checks of one example: docs-example NAME (a docs/examples/ directory) |
| `docs-e2e` | docs | real NixOS, nix-darwin and home-manager evaluations of the examples |
| `docs-check` | docs | nix flake check of docs/: pages and workflows current |
| `docs-dev` | docs | the site at localhost:4321, live |
| `docs-build` | docs | build the site to docs/dist |
| `engine-test` | engine | the engine and library suites |
| `engine-cost` | engine | the memo cost oracles |
| `lean-check` | engine | build the Lean checker: its build checks the proofs, the examples, and no sorry (CI builds it in docs-check) |
| `each-flake` | flake | run command in every flake.nix directory that has it |
| `fmt-check` | fmt | every tracked nix file is formatted (nixfmt), as CI checks |
| `lint` | fmt | the workflows are valid (actionlint, with shellcheck) |
| `fmt` | fmt | format every tracked nix file (nixfmt) |
| `issue-eval` | issue | issue-eval BODY DIR: an issue's nix blocks as one fleet, restricted; writes DIR/comment.md |
| `issue-comment` | issue | issue-comment NUMBER FILE: post FILE on issue NUMBER, replacing yen's last comment (needs GH_TOKEN) |
| `reference-test` | reference | the reference fleet's checks |
| `reference-e2e` | reference | the reference fleet's real evaluations |
| `reference-cost` | reference | the trimmed-module-list cost oracle |
| `reference-mcp` | reference | the MCP server tests |
| `reference-check` | reference | nix flake check of the fleet (VM tests are vmTests, not checks) |
| `reference-eval` | reference | reference-eval SYSTEM: every ci.json target of SYSTEM evaluates to a derivation |
| `reference-write` | reference | regenerate the reference fleet's README.md and ci.json |
| `reference-flake` | reference | regenerate the reference fleet's flake.nix |

## Generated files

Do not edit generated files. Edit their source, then run the generator. A check fails when a committed file is stale.

The site pages (`docs/src/content/docs/**`) and `docs/src/sidebar.json` are not committed: `docs-build`
and `docs-dev` write them from `docs/examples/*/page.nix` first. The table lists the generated files that are
committed, because GitHub reads them from the repository:


| Files | Source | Generator |
|---|---|---|
| `.github/workflows/test.yml` | `docs/modules/ci.nix` | `docs-write` |
| `.github/workflows/issue.yml`, `.github/ISSUE_TEMPLATE/*` | `docs/modules/issues.nix` | `docs-write` |
| `CONTRIBUTING.md` | `docs/examples/contributing/page.nix` | `docs-write` |
| `reference/README.md`, `reference/ci.json` | `reference/modules/docs/` | `reference-write` |
| `reference/flake.nix` | the `flake-file` sink of the fleet | `reference-flake` |

## Which task to run, and when

Run the fast tasks while you work, push, and leave the heavy ones to CI. Do not wait for a heavy task on your machine.
Put `timeout 300` before any command that can run long: an evaluation that does not finish is a finding to report,
not a reason to wait. Run a slow task in the background and read its output when it ends.

Fast, run them often:


| You changed | Run while you work |
|---|---|
| an example under `docs/examples/` | `docs-example NAME` for that example, then `docs-test` |
| the engine (`default.nix`, `lib/`) or a battery | `engine-test`, and the `docs-example` of the page that shows it |
| the reference fleet (`reference/`) | `reference-test` |
| any Nix file | `fmt`, last |

Before every push, run the generator of every generated file whose source you changed (see the table above).
A red CI job that says a file is stale means you did not run its generator. The two that are easy to forget:

- `docs-write` writes `README.md`, `CONTRIBUTING.md` and the workflows (and the site pages, which are not committed).
- `reference-write` writes the reference fleet's README, which lists engine names such as the reduce strategies and the
  library functions. A change to the engine often changes both, so run both.

Heavy, leave them to CI:


| Task | Why it waits for CI |
|---|---|
| `docs-e2e`, `reference-e2e` | real NixOS, nix-darwin and home-manager evaluations |
| `engine-cost`, `reference-cost` | cost oracles over whole evaluations |
| `reference-check`, `reference-eval`, `docs-check`, `docs-build` | a flake check or a build of every output, or of the site |
| `reference-mcp` | builds the Rust server |
| `ci` | every stage in one terminal, one after another |

Fix a failed push with a new commit on the same branch. Do not rewrite pushed history.

## CI

CI runs in stages, one after another, so a push does not start every job at once: `fmt`, `engine`, `docs`, `fleet`,
then `flake-check` and one evaluation job per system. `ci` in the devshell runs the same stages locally, except the last.
The `aarch64-darwin` evaluation is not binding (`continue-on-error`): a darwin runner can take long to come, so a
merge does not wait for it.

## Maintenance

- **Update inputs.** Run `nix flake update` in `docs/` and in `reference/`, then `ci`. nixpkgs comes from the
  nixos.org channel tarballs, not from GitHub.
- **After a nixpkgs update**, the reference fleet's trimmed module lists belong to the old revision: `reference-e2e` fails on
  `modlist-same-drv` until they are computed again.
- **Format** with `fmt`; CI checks it with `fmt-check`.
- **A new error code** in the engine fails the docs until the Error codes page (`docs/examples/errors-reference`) explains it.

