let
  link = text: path: "[${text}](${path})"; # absolute links
  # the fleet staged with the change: a host in `lab` that uses the prod database
  stagedOf =
    engine: inputs: dir:
    engine.stage {
      base = {
        imports = [ (inputs.import-tree (dir + "/modules")) ];
        inherit inputs;
        inherit (inputs.nixpkgs) lib;
        yen.sinks = {
          inputs = { };
          lib = { };
        };
      };
      change = dir + "/changes/api-in-lab.nix";
    };
  verdictOf = s: {
    inherit (s) ok violations;
    added = s.diff.scopes.added;
  };
in
{
  title = "A fleet on one page";
  description = "Two environments, three hosts, a user, a service placed by a fact, and a rule across machines. One file.";
  section = "start";
  order = 4;

  body =
    {
      docs,
      inputs,
      dir,
      engine,
      result,
      ...
    }:
    [
      ''
        **Yen is a verified language for Nix configurations**: one file of Nix builtins, with no dependencies, no module system,
        no fixpoint and no `throw`. You describe a fleet as data and behavior, and Yen checks it and answers with the systems to build,
        the errors, the graph of who gives what to whom, and whether your rules hold across machines.

        Yen is domain independent. Its engine doesn't know what a host, a user or NixOS is. You name your own nouns,
        so it configures NixOS, nix-darwin, home-manager, clusters, terraform or anything else you can model as Nix values.
        For reuse, [`yen.lib.batteries`](/batteries/) are functions from roles to a Yen module, and you give every name. Domain batteries
        like `yen.lib.batteries.nixos` fill those roles with one domain's options.

        ${link "Documentation" "/"} · ${link "Getting started" "/start/getting-started/"} · [Reference fully-featured fleet](https://github.com/vic/yen/tree/main/reference) · [vic/vix on yen](https://github.com/vic/vix/tree/yen) · [Sponsor vic](https://dendritic.oeiuwq.com/sponsor)

        ## Four words

        See the [glossary](/reference/glossary/) for every term.

        - **[Kinds](/model/kinds-fields/)**: your nouns, typed. `yen.kinds.host.fields.addr = yen.lib.str;`
        - **[Scopes](/model/scopes/)**: where things live. `spawns` builds a tree from your data, like a user under each host it's on.
        - **[Aspects](/behavior/aspects/)**: behavior, active where a predicate holds: a kind, an instance, another aspect, or any fact.
        - **[Sinks](/behavior/sinks/)**: where elements go. An element goes up to the nearest scope that collects it, and the sink reduces them.

        Data is queried, not merged. Each read is a query on the files that answer it, so content in many files never
        overwrites itself, and an error is a record you can read.

        ## A fleet on one page

        Two environments, three NixOS hosts, a user on two of them, postgres placed by a fact (some host names it as its
        database), and a rule that holds across machines. Every line runs, since these files are a tested template
        (plus a `hardware.nix` stub so NixOS evaluates). The first file declares the kinds:
      ''
      (docs.fileNoted "" "modules/kinds.nix")
      ''
        At `(1)` the root `fleet` spawns every `env`, and at `(2)` an `env` spawns the hosts that point at it with their
        `env` field. At `(3)` a host's `os` sink feeds the `nixos` sink, so an element for `os` becomes a NixOS module,
        and at `(4)` the `nixos` sink builds the system with `nixosSystem`. The second file is the data, plain instances that refer to each other:
      ''
      (docs.fileNoted "" "modules/data.nix")
      ''
        At `(1)`, `web` refers to the instance `prod`, not to a string. At `(2)` the user `ana` is on two hosts, so a
        `user` scope spawns under each (see [instances and refs](/model/instances-refs/)). The third file is the behavior and the rule:
      ''
      (docs.fileNoted "" "modules/behavior.nix")
      ''
        At `(1)` the `names` aspect is active at every host. At `(2)` `postgres` is active where a fact holds, namely that
        some host uses this one as its `db`. At `(3)` the `db-same-env` [invariant](/query/invariants/) says that
        a host's database must be in that host's environment. Each element goes up to the nearest `os` sink.

        Now ask it. The tree comes from the data:
      ''
      (docs.value (map (s: s.id) result.scopes))
      ''
        ## Change it safely

        An agent proposes a host in `lab` that uses the prod database. Here's the change:
      ''
      (docs.file "changes/api-in-lab.nix")
      ''
        [`yen.lib.stage`](/agents/stage/) evaluates the fleet without and with the change, applies nothing, and refuses it with
        the rule it breaks:
      ''
      (docs.value (verdictOf (stagedOf engine inputs dir)))
      ''
        ## What else it does

        - **Graphs, Datalog and µKanren, in pure Nix**: deploy waves, well-founded models with proofs and why-not, and values
          synthesized under constraints (a free port, guest memory that fits). ${link "Ask and prove" "/query/queries/"}
        - **Agents as team members**: every answer is JSON-safe data. Changes are staged, checked by invariants, limited by
          grants that only narrow, and written as change programs, and an MCP server answers agents. ${link "For agents" "/agents/agent-surface/"}
        - **Errors with fixes**: `code`, `path`, `got`, `want`, `fix`, and `near` for typos. ${link "Errors as data" "/principles/errors/"}
        - **Fast where it counts**: one nixpkgs per system across hosts, and trimmed NixOS module lists, with drvPath oracles
          that prove the systems are the same. ${link "Performance" "/perf/shared-pkgs/"}
        - **Every capability of Den, den-hoag and clan**, plus the patterns of real fleets, each with a check, in the
          [reference fleet](https://github.com/vic/yen/tree/main/reference). ${link "From Den" "/migrate/from-den/"}

        ## Start
      ''
      (docs.sh "nix flake init -t github:vic/yen#one-page-fleet")
      ''
        Then read the ${link "documentation" "/"}, where every page is a tested example. Coming from `configuration.nix`, a flake or Den?
        The ${link "migration guides" "/migrate/from-configuration-nix/"} build the same systems before and after.

        Yen is made by [vic](https://github.com/vic), with love, as part of the [Dendritic ecosystem](https://dendritic.oeiuwq.com).
        If it helps you, please [sponsor vic](https://dendritic.oeiuwq.com/sponsor). Issues and pull requests are welcome
        (see [CONTRIBUTING.md](CONTRIBUTING.md)).
      ''
    ];

  checks =
    {
      result,
      inputs,
      dir,
      engine,
      eq,
      yes,
      no,
      ...
    }:
    {
      ok = yes (result.check.ok);
      postgres-by-fact = {
        t1 = yes (result.active.postgres."fleet:main/env:prod/host:db");
        t2 = no (result.active.postgres."fleet:main/env:prod/host:web");
      };
      # one stage, one comparison: refused, with the rule it breaks
      refused = eq (removeAttrs (verdictOf (stagedOf engine inputs dir)) [ "added" ]) {
        ok = false;
        violations = [
          [
            "bad"
            "db-same-env"
            "fleet:main/env:lab/host:api"
          ]
        ];
      };
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
      account-on-box = yes (flake.nixosConfigurations.box.config.users.users.ana.isNormalUser);
      postgres = yes (flake.nixosConfigurations.db.config.services.postgresql.enable);
      fqdn = eq (flake.nixosConfigurations.web.config.networking.fqdn) ("web.example.com");
    };
}
