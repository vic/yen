# Agents

Read this file, then read the files below, before you write any code. A change that ignores them is rejected in review.

## Read first

1. [CONTRIBUTING.md](CONTRIBUTING.md): the coding standards for `lib/`, `tests/` and Yen modules, how to test, and the
   rules for batteries, kits and assemblies. It is generated from `docs/examples/contributing/page.nix`: edit that file, not `CONTRIBUTING.md`.
2. The [Style guide](https://yen.oeiuwq.com/principles/style/): how a fleet author writes a Yen module.
3. Two or three examples and their `page.nix` files in `docs/examples/` that are close to your change. An example is a page,
   a flake template and a test at once. Copy the form of the nearest one.
4. For a battery, kit or assembly: two or more existing ones in `lib/batteries/`, `lib/kits/` and `docs/examples/kits-*`. They are
   pluggable and composable, and each rule in CONTRIBUTING comes from a review that found its absence.

## Rules that agents break most

- One `let` per file, at the top. No `rec`, no `with`, no `import` in `lib/`. `b = builtins;` and name each attribute you use.
- No `throw`, `abort` or `assert` in new engine code: return an error record.
- A type, not an `if`. A ref, not a string. A function that exists in `lib/_core/` is not written again.
- A battery is the value of one key of a fleet that exists. It sets no name of the fleet, evaluates nothing, reads no
  project file and produces no flake.
- Every new check comes with a mutant: change the code, see the check fail, change it back. One test runs in under a second.
- Do not set up a workaround for an error. Find the invariant that is broken, and fix it where it is written.

## Work in this order

1. Write the example or the test first, and see it fail.
2. Make the change, and see it pass.
3. Run `fmt`, then `docs-write` and `reference-write` when the docs or the reference fleet changed. The generated pages are
   a build output and are not committed. `README.md`, `CONTRIBUTING.md` and the workflows are committed and must match.
4. Run `docs-test` and the suite of your topic. Run e2e and `flake check` in CI, not on your machine.

Say plainly what you ran and what you did not run. A claim of "done" with no command output is not accepted.

## Pull requests

Open one pull request for one change. Add a commit on top to fix a review. Do not force-push.
