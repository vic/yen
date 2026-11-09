{
  title = "Repo batteries";
  description = "files, github, devshell, flake-file: README, CI workflow, ci.json, dev shell and flake.nix, written from fleet data.";
  section = "batteries";
  route = "batteries/repo";
  order = 5;

  body =
    { docs, result, ... }:
    [
      ''
        Some files in a repo should follow the code: the README, the CI workflow, a matrix of CI targets, the dev shell,
        `flake.nix`. [Batteries](/batteries/) write them from [sinks](/behavior/sinks/), so any
        [aspect](/behavior/aspects/) can add a section, a job, a target or an input.
        [github:sini/files](https://github.com/sini/files) writes them (`nix run .#write-files`) and gives a check for
        each file, so CI fails when a committed file goes stale.

        The repo is one root [scope](/model/scopes/) that writes repo files, plus one scope per system for its dev shell:
      ''
      (docs.fileNoted "" "modules/repo.nix")
      ''
        `(1)` is the repo's `files` sink, and every key that gives to it becomes a repo file. `files.writer` builds
        `packages.<system>.write-files` and a check for each file. `(2)` builds `devShells.<scope name>.default` from the
        system scopes' `{ packages; shellHook; }` records.

        A README made of sections from any file:
      ''
      (docs.fileNoted "" "modules/readme.nix")
      ''
        `(1)` is the `ordered` [reduce](/batteries/generic/#sections-from-many-files), so sections come in an order that
        meets every `before` and `after`. At `(2)`, `files.document` writes one file from the sink's texts. `(3)` is a
        notice in the comment syntax of the file's format.

        A CI workflow and a matrix of targets:
      ''
      (docs.fileNoted "" "modules/ci.nix")
      ''
        `(1)` writes a workflow from a sink of jobs, and `(2)` is its header. `(3)` writes the targets sink as JSON to `ci.json`.

        A `flake.nix` written from the inputs each aspect declares:
      ''
      (docs.fileNoted "" "modules/flake-file.nix")
      ''
        `(1)` writes `flake.nix` with [flake-file](https://github.com/vic/flake-file), and gives
        `packages.<system>.write-flake` with its check.

        More repo files, and a dev shell whose commands can come from any aspect:
      ''
      (docs.fileNoted "" "modules/more.nix")
      ''
        `(1)` and `(2)` make TOML and YAML text from Nix values, and `(3)` makes a numtide/devshell for each system.

        Here are the files the aspects give, as the files sink holds them:
      ''
      (docs.value (
        map (m: builtins.mapAttrs (_: f: f.text) m.files.file) result.reduced.files."repo:main"
      ))
      ''
        ## The batteries

        | Battery | Value of | Writes |
        |---|---|---|
        | `files.writer { from; files; lib; pkgs; root; relativeRoot; }` | `out` of the files sink | `packages.<system>.write-files` and a check per file |
        | `files.document { from; path; separator; }` | a key that gives to the files sink | one file from the texts of a sink (with `ordered`: sections in order) |
        | `files.json { from; path; value; }` | the same | the JSON of a sink |
        | `files.toml { inline; }` | a function | TOML text from a Nix value |
        | `files.comment path text` | a function | a notice in the comment syntax of the file's format |
        | `github.workflow { from; path; doc; header; }` | a key that gives to the files sink | a workflow from a sink of jobs |
        | `github.yaml` | a function | YAML text from a Nix value |
        | `devshell.mkshell { from; pkgsOf; }` | `out` of a sink of `{ packages; shellHook; }` | `devShells.<scope name>.default` |
        | `devshell.numtide { from; devshell; systems; pkgsOf; name; packages; }` | `out` of a sink of command lists | a numtide/devshell per system |
        | `flake-file.write { from; lib; inputs; pkgs; modules; }` | `out` of a merge sink | `packages.<system>.write-flake` and its check |
      ''
    ];

  checks =
    {
      result,
      eq,
      yes,
      no,
      ...
    }:
    let
      texts = builtins.foldl' (
        a: m: a // builtins.mapAttrs (_: f: f.text) m.files.file
      ) { } result.reduced.files."repo:main";
    in
    {
      readme = eq (texts."README.md") (
        "# my repo\n<!-- Generated. Run nix run .#write-files. -->\n\n## Usage"
      );
      workflow = eq (texts.".github/workflows/ci.yml") (
        "# Generated. Jobs: check\n\"jobs\":\n  \"check\":\n    \"runs-on\": \"ubuntu-latest\"\n    \"steps\":\n      -\n        \"uses\": \"actions/checkout@v4\"\n      -\n        \"run\": \"nix flake check\"\n\"name\": \"ci\"\n\"on\":\n  \"push\": {}\n"
      );
      json = eq (texts."ci.json") ("[\"devShells.x86_64-linux.default\"]\n");
      toml = eq (texts."taplo.toml") ("[formatting]\nalign_entries = true\n");
      yaml = eq (builtins.substring 0 14 texts.".github/dependabot.yml") ("\"updates\":\n  -");
      outputs = eq (builtins.attrNames result.flake.packages.x86_64-linux) ([
        "write-files"
        "write-flake"
      ]);
    };

  e2e =
    {
      flake,
      eq,
      yes,
      no,
      ...
    }:
    {
      write-files = yes (builtins.isString flake.packages.x86_64-linux.write-files.drvPath);
      write-flake = yes (builtins.isString flake.packages.x86_64-linux.write-flake.drvPath);
      file-checks = eq (builtins.length (
        builtins.attrNames (removeAttrs flake.checks.x86_64-linux [ "yen-lean" ])
      )) (6);
      lean-check = yes (flake.checks.x86_64-linux ? yen-lean);
      numtide = yes (builtins.isString flake.devShells.x86_64-linux.repo.drvPath);
      shell = yes (builtins.isString flake.devShells.x86_64-linux.default.drvPath);
    };
}
