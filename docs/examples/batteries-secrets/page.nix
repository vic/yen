let
  # the text of each file the repo scope writes
  textsOf =
    result:
    builtins.foldl' (
      a: m: a // builtins.mapAttrs (_: f: f.text) m.files.file
    ) { } result.reduced.files."repo:main";
in
{
  title = "Caches and secrets batteries";
  description = "cachix caches trusted by hosts and the flake, pushed from CI; secretspec.toml and .sops.yaml from what each feature declares.";
  section = "batteries";
  route = "batteries/secrets";
  order = 7;

  body =
    {
      docs,
      result,
      ...
    }:
    [
      ''
        A cache and a secret are data. The host trusts a cache, the flake asks to trust it, and CI pushes to it.
        A feature declares the secrets it needs, and a file lists them. [Batteries](/batteries/) write these from [sinks](/behavior/sinks/).
        This fleet has one NixOS host and a repo root that writes files:
      ''
      (docs.file "modules/fleet.nix")
      ''
        Any [aspect](/behavior/aspects/) adds a cache to the sinks. The CI job that pushes to the cache:
      ''
      (docs.fileNoted "" "modules/caches.nix")
      ''
        A cache is `{ name; publicKey; url ? "https://<name>.cachix.org"; }`. `(1)` gives the host `nix.settings` substituters
        and trusted keys. `(2)` gives the flake `nixConfig` extra-substituters and keys. At `(3)`, `github.workflow` writes
        the workflow from a sink of jobs, as on [Repo batteries](/batteries/repo/). `(4)` is a workflow step: `cachix/cachix-action`,
        which pushes what the job builds. This is the `nixConfig` of the flake:
      ''
      (docs.value result.flake.nixConfig)
      ''
        Secrets are declared by the features that need them. The values live in a provider, never in git:
      ''
      (docs.fileNoted "" "modules/secrets.nix")
      ''
        A secret is `{ name; profile ? "default"; … }` with any [secretspec](https://github.com/cachix/secretspec) field.
        At `(1)`, `claim` is the [reduce](/batteries/generic/#one-owner-per-key): a secret that two [scopes](/model/scopes/) declare is an error.
        `(2)` writes `secretspec.toml`. `(3)` writes `.sops.yaml` from a sink of creation rules. These are the files:
      ''
      (docs.code "toml" (textsOf result)."secretspec.toml")
      (docs.code "yaml" (textsOf result).".sops.yaml")
      ''
        ## The batteries

        | Battery | Value of | Gives |
        |---|---|---|
        | `cachix.caches { from; }` | a NixOS, nix-darwin or home-manager key of a sink of caches | `nix.settings` substituters and trusted keys |
        | `cachix.flake-config { from; }` | a flake-level key | flake `nixConfig` extra-substituters and keys |
        | `cachix.action { name; authToken; version; }` | a workflow step | `cachix/cachix-action`, which pushes what the job builds |
        | `secretspec.toml { from; project; defaults; providers; profiles; }` | a key that gives to the files sink | `secretspec.toml` |
        | `secrets.sops-config { from; path; }` | the same | `.sops.yaml` from a sink of creation rules |
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
    {
      flake-config = eq (result.flake.nixConfig.extra-substituters) ([
        "https://nix-community.cachix.org"
      ]);
      secretspec = eq ((textsOf result)."secretspec.toml") (
        "[defaults]\nproviders = [\"keyring\"]\n\n[profiles.default]\nDATABASE_URL = { description = \"PostgreSQL connection string\" }\n\n[profiles.development]\nDATABASE_URL = { default = \"sqlite://./dev.db\", required = false }\n\n[project]\nname = \"my-app\"\n"
      );
      sops = eq ((textsOf result).".sops.yaml") (
        "\"creation_rules\":\n  -\n    \"age\": \"age1db\"\n    \"path_regex\": \"secrets/db/.*\"\n"
      );
      action = yes (
        builtins.match ".*cachix/cachix-action@v17.*" (
          builtins.replaceStrings [ "\n" ] [ " " ] (textsOf result).".github/workflows/build.yml"
        ) != null
      );
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
      substituters = yes (
        builtins.elem "https://nix-community.cachix.org" flake.nixosConfigurations.build.config.nix.settings.substituters
      );
      keys = yes (
        builtins.any (
          k: builtins.substring 0 13 k == "nix-community"
        ) flake.nixosConfigurations.build.config.nix.settings.trusted-public-keys
      );
    };
}
