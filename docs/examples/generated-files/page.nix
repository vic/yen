{
  title = "Generated files";
  description = "flake.nix by flake-file, README.md and the CI workflow by sini/files: written from fleet data, and checked in CI.";
  section = "recipes";
  order = 7;

  body =
    { docs, result, ... }:
    [
      ''
        Some repo files are views of your fleet: the flake's inputs, a README with the host diagram, a CI workflow.
        Write them from the data, and a check fails when a committed file is stale.
        [denful/flake-file](https://github.com/denful/flake-file) writes `flake.nix`.
        [sini/files](https://github.com/sini/files) writes `README.md` and the CI workflow. yen gives both the content.

        These docs are made this way: every page you read is a file that the docs fleet writes. So is yen's CI workflow:
        each stage is an [aspect](/behavior/aspects/), and one job per system comes from the reference fleet's `ci.json`
        ([docs/modules/ci.nix](https://github.com/vic/yen/blob/main/docs/modules/ci.nix)).
      ''
      (docs.fileNoted "{12,22,41-56}" "modules/fleet.nix")
      ''
        The kind `fleet` has two [sinks](/behavior/sinks/) that write files. At `(1)`, `flakeFileOf` evaluates the `flake-file`
        options. At `(2)`, `filesOf` evaluates the `files` modules. At `(3)`, the `flake-file` sink reduces the inputs that
        aspects declare. At `(4)`, it gives the app that writes `flake.nix`. At `(5)`, the `files` sink gives the writer of the other files.
        At `(6)`, a check fails when a committed file is stale.

        ## Inputs live with their users

        Each [aspect](/behavior/aspects/) declares the flake inputs it uses on the `flake-file` sink:
      ''
      (docs.fileNoted "{27}" "modules/inputs.nix")
      ''
        At `(1)`, `core-inputs` is active at the fleet. At `(2)`, it declares the inputs of the template. At `(3)`, the
        input of the host goes up to the fleet.

        ## README and CI workflow

        The `files` sink collects `sini/files` modules. One aspect writes the README, with a single mermaid diagram of the fleet's hosts, and the CI workflow:
      ''
      (docs.fileNoted "" "modules/write.nix")
      ''
        At `(1)`, a tree request for the whole fleet. At `(2)`, the [cycle](/behavior/cycle/) asks it. At `(3)`, the key `files`
        gives the modules that write `README.md` and the CI workflow.

        The template's own `flake.nix` is the `flake-file` output. Remove the `web` aspect, and `nixpkgs` leaves the flake.
      ''
      (docs.file "flake.nix")
      (docs.file "README.md")
      (docs.file ".github/workflows/ci.yml")
      (docs.sh ''
        nix run .#write-flake   # write flake.nix
        nix run .#write-files   # write README.md and the CI workflow
        nix flake check         # fails when a committed file is stale
      '')
    ];

  checks =
    {
      result,
      dir,
      eq,
      yes,
      no,
      ...
    }:
    let
      gen = (builtins.head result.reduced.files."fleet:main").files.file;
    in
    {
      readme = eq (gen."README.md".text) (builtins.readFile (dir + "/README.md"));
      readme-mermaid = yes (builtins.match ".*```mermaid\n.*" gen."README.md".text != null);
      ci = eq (gen.".github/workflows/ci.yml".text) (
        builtins.readFile (dir + "/.github/workflows/ci.yml")
      );
      inputs = eq (builtins.attrNames result.reduced.flake-file."fleet:main".inputs) ([
        "files"
        "flake-file"
        "import-tree"
        "nixpkgs"
        "nixpkgs-unstable"
        "yen"
      ]);
    };
}
