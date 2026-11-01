let
  link = text: path: "[${text}](${path})"; # absolute: this page is also the repository README
  doc = path: "<sup>[docs](${path})</sup>"; # a small link after a point, so the prose stays clean
  # the two hosts of variants/invariant.nix, as a caller outside the fleet names them: their identity
  web = {
    kind = "host";
    name = "web";
  };
  db = web // {
    name = "db";
  };
in
{
  title = "Why Yen";
  plainTitle = "Yen: Nix fleets you can formally verify before deployment.";
  description = "Yen is a cycle.js based language for Nix configurations";
  section = "start";
  order = 1;
  alsoAt = "../README.md"; # the same text is the repository README: plain markdown only

  body =
    { docs, variant, ... }:
    [
      ''

        **Yen is a minimal pure-Nix language for verified fleet configurations**: no dependencies, no nixpkgs module system.
        You describe your fleet as terms ${doc "/model/kinds-fields"} and the relationships between them ${doc "/model/scopes"}. Yen answers queries ${doc "/query/queries"} about it: which systems to build,
        verification errors, dependency graphs of who gives what to whom, and whether your invariant rules hold across all machines.

        Yen is built on four concepts: **kinds**, **scopes**, **aspects** and **sinks**. The Yen kernel knows nothing about
        NixOS, but it can describe fleets over any configuration domain: NixOS, nix-darwin, home-manager, clusters, terraform, k8s,
        or anything else you can model as Nix values. You define your own domain language, and Yen uses it.


        ${link "Documentation" "/"} · ${link "Getting started" "/start/getting-started/"} · ${link "A fleet on one page" "/start/one-page-fleet/"} · [Reference fleet](https://github.com/vic/yen/tree/main/templates/fleet) · [vic/vix@yen](https://github.com/vic/vix/tree/yen) · [Sponsor vic](https://dendritic.oeiuwq.com/sponsor)


        ## The Cycle model

        Yen is designed around [Cycle.js](https://cycle.js.org) and other functional reactive programming principles.
        As in Cycle, an aspect ${doc "/behavior/aspects"} is a cycle ${doc "/behavior/cycle"} function `sources -> sinks`. It sends requests through its `sinks` to its parent cycles
        to observe the world, and it gets their answers back through `sources`. A yen module ${doc "/principles/modules"} follows the same model: its args are
        `sources`, and every key it gives, other than `imports` and `yen`, is a module sink that any module can read.

        For example, a user aspect can ask which host it lives on, or whether a service is enabled somewhere else in the fleet.
        Most of the time, aspects are simple and look like plain Nix configurations. They need no knowledge of the underlying query model.


        ## Main Concepts

        - **Kinds**: the nouns of the things in your fleet, and their typed fields.
        - **Scopes**: how kinds nest inside each other. `.spawns.` builds the nested cycles from your data: a user under each host.
        - **Aspects**: reactive behavior. `.at` sets a predicate that must hold for the behavior to be active: a kind, an instance of a kind, another aspect, or any custom predicate.
        - **Sinks**: data channels. A configuration element goes up to the nearest scope that collects a sink, and that scope decides how to reduce all the contributions.

        ## Yen Flake example

        Yen has no dependencies. It is built only on Nix `builtins`. This is the most basic flake
        that takes a single Yen module.

      ''

      (docs.file "flake.nix")

      ''

        Yen imposes no domain language, so you can define the nouns of your own world, how they relate to each other,
        and how they contribute to the final Nix configuration.

      ''

      (docs.file "modules/hello.nix")

      ''

        The output of this flake looks like this:

      ''

      (docs.file "result.nix")

      ''

        ## Design Principles

        Unlike the nixpkgs module system, where a type's `check` and `merge` are part of the same definition, Yen keeps data validation
        separate from the `reduce` (merge) strategy. Each sink boundary defines how data is collected or transformed. Data is queried
        instead of being merged into one global `config` attribute.

        Yen treats errors as data. Since every relationship and read between kinds is traceable, Yen can build a dependency graph
        showing what reads from what, and where the data comes from.

        From your definitions, Yen derives logic facts and relationships. You use them with logic variables to state invariants
        that must hold across the parts of your fleet before it can even be built. Think of them as formal constraints over
        services or fleet members.


        ## Two Logic Languages

        Yen ships two pure-Nix logic languages to help you deploy in waves: well-founded models with proofs, why-not explanations,
        and values synthesized under constraints ${doc "/query/queries"}.

        µKanren-style logic programs let you synthesize configurations from constraints. For example, allocate a free port,
        or compute a VM's memory so it takes only a percentage of its host.

        Datalog facts describe invariants about your fleet. For example, you can state that a web server and its database
        must be in the same region or environment.

      ''
      (docs.file "variants/region.nix")
      ''

        Fields, aspects and variables are references, not strings: a typo is an evaluation error. An `api` host in region `eu`
        that points at a database in `us` gives `[ "bad" "db-same-region" "fleet:main/region:eu/host:api" ]`, and the fleet
        builds nothing until it is fixed.

        ## Answers come with a reason

        Logic questions about your fleet get answers you can read. `result.check.why` gives the rules that make a violation
        true. `result.check.whyNot` works the other way. For an atom that is not true, it gives each rule with that head, and
        the body atoms that stop it. For an atom that is true, it gives nothing. A question is a literal, by reference:
        `result.check.bad.<invariant> host`, with the host an instance (or `{ kind; name; }` from outside the fleet).
      ''
      (docs.file "variants/invariant.nix")
      ''

        Here `web` breaks the rule, and `db` does not. The violation for `web`:
      ''
      (docs.value (variant "variants/invariant.nix").check.violations)
      ''
        `whyNot` for `db` says that no rule has this head. The desktop aspect is only active at `web`, so the rule
        is not even a candidate at `db`.
      ''
      (docs.value (
        let
          inv = (variant "variants/invariant.nix").check;
        in
        inv.whyNot (inv.bad.no-desktop-on-servers db)
      ))
      ''

        ## Values from constraints

        `yen.lib.krn` finds values that fit your constraints, and a relation can run backward.
      ''
      (docs.file "variants/ports.nix")
      (docs.value (variant "variants/ports.nix").reduced.greetings."world:earth".ports)
      ''
        `first` is one answer, and `count` is every answer.

        ## Checks before a change lands

        Yen checks the whole fleet before a change reaches a file. A rule is a function of its variables, and it names what it
        breaks. A rule can hold across machines, so a mistake that involves two hosts gets caught too. These are easy to make in a
        homelab: a desktop on a server, or two hosts with the same address.

        A change is staged before it is written. `yen.lib.stage` evaluates the fleet without the change and with it. `ok` is true
        only when nothing new is wrong. A grant made with `yen.lib.grant` limits the scopes a change may reach, and a grant can only narrow.

        Each verdict can come with a certificate. `yen.lib.datalog.checkCertificate` is a small checker. After evaluation,
        `result.check.certified` is true when the checker accepts the certificate and it states the same verdict. `result.check.seal`
        ties the verdict to hashes of the engine, the rules and the facts, so anyone can run `result.check.verify seal` again and get
        `{ ok = true; }`.

        ## Agents as first-class team members

        Everything in Yen is expressed as a query, and every answer is JSON-safe data. Agents can propose changes to your
        infrastructure, and those changes are verified **before** any file is edited. Changes are staged, checked against
        invariants, limited by grants that can only narrow, and written as change programs. An MCP server answers agents and
        lets them write only verified changes. ${doc "/agents/agent-surface"}

        ## How agents check a change

        An agent works on a Yen fleet through the MCP server in `mcp/`. The skill in `.claude/skills/yen-mcp/SKILL.md` gives the
        order of calls. The agent reads with `yen_schema` and `yen_check`, asks with `yen_why_not` and `yen_explain`, and stages a
        change with `yen_stage` before any file is written. A fleet passes `yen_check` only when `ok` is true, with no violations,
        no `incomplete` or `opaque` atoms, and `certified` true.

        From the fleet's working directory, run `nix run github:vic/yen?dir=mcp`. An MCP client starts the same server with
        the arguments `[ "run" "github:vic/yen?dir=mcp" ]`.

        The agent can show the staged answer to a person, with its violations, its diff and its refusals. A refusal with
        `class = "authority"` is not for the agent to fix. The agent tells the owner what it wanted to change, and why.

        ## Errors are data

        Errors are not throws. They are data that agents and humans can inspect, with **hints for fixes**: `code`, `path`,
        `got`, `want`, `fix`, and `near` for typos. ${doc "/principles/errors"}

        ## Yen Capabilities

        - **Errors you can read.** Yen never throws. A typo gets a "did you mean", and each error gives its place, what was
          expected, and a fix. Agents read the same records. ${doc "/principles/errors/"}
        - **Queries, not merges.** Each value is a query on the files that declare it. Content spread over many files never
          overwrites itself, and two different answers without explicit reduce strategy are an error. ${doc "/principles/queried-not-merged/"}
        - **Rules across machines.** Write a rule once. A fleet that breaks it builds nothing. Each verdict comes with a proof
          that a small checker verifies, and a seal anyone can check again. ${doc "/query/invariants/"}
        - **Changes staged before they land.** `yen.lib.stage` compares the fleet with and without a change. A grant narrows
          what a change may reach, and never widens it. ${doc "/agents/stage/"}
        - **Ask your fleet anything.** Graphs for deploy waves, cycles and impact. Datalog with negation. Stored queries you
          name once and ask from Nix, the CLI or an agent. ${doc "/query/queries/"}
        - **Values that solve themselves.** µKanren with finite domains: a free port, guest memory that fits, relations that
          run backward. ${doc "/query/krn/"}
        - **Batteries and kits.** Ready rules in `yen.lib.batteries`, and ready parts in `yen.lib.kits`: wireguard, dns, sshd,
          backups, monitoring, postgres and more. You write the keys, the battery gives the values. ${doc "/batteries/"}
        - **Every platform.** NixOS, nix-darwin, home-manager, nix-on-droid and microvm.nix. One aspect can serve them all.
          ${doc "/batteries/platforms/"}
        - **Generated files.** README, CI workflow, `flake.nix` and dev shell, written from fleet data. ${doc "/recipes/generated-files/"}
        - **Secrets by name.** Secrets are data. A host gets exactly the secrets that name it. ${doc "/recipes/secrets/"}
        - **Time and impact.** See what a host reaches, and which instances are valid at a given date. ${doc "/agents/history/"}
        - **Less to evaluate.** Yen itself is about 1% of a host's evaluation. One nixpkgs per system instead of one per host
          saves about a third, and a check proves every system is the same. ${doc "/perf/shared-pkgs/"}
        - **On par with Den.** Hosts, users, homes, includes, defaults, batteries, guests, roles and secrets. Moving from Den is
          easy. ${doc "/migrate/from-den/"}
        - **Ready for agents.** Every answer is JSON-safe data. An agent asks about your fleet, stages a change, and sees why it
          is refused, before anything is applied. Yen ships an MCP server and a skill for it. ${doc "/agents/mcp/"}
        - **Just Nix.** Yen uses Nix builtins only, with no dependencies. It has no `throw`, no options and no `config`.
        - **Assemblies and kits.** Build a machine from members, with layered settings, exports and contracts. Ready-made kits
          cover backups, wifi, remote builders, binary caches, monitoring and postgres. ${doc "/recipes/assemblies/"} ${doc "/batteries/kits/"}
        - **Roles.** A role is an aspect that applies where a fact holds, so no host file lists its roles. ${doc "/behavior/predicates/"}
        - **Environments and cascades.** Group hosts by where they run, and let settings fall back along an ordered list. ${doc "/recipes/environments/"}
        - **Guests.** Containers and VMs live under their host, and their config goes into the host. ${doc "/recipes/guests/"}
        - **One aspect, many platforms.** A sink forwards its content to a platform's class, so one feature serves NixOS and home-manager. ${doc "/behavior/forwards/"}
        - **Install and deploy.** Disk layouts as data, with install and rebuild apps. ${doc "/batteries/install/"}
        - **Derived network config.** known_hosts, WireGuard peers and Syncthing devices are built from the other hosts. ${doc "/batteries/kits-network/"}
        - **Editors and agent tools.** VS Code, Zed and one shared pool of agent skills and MCP servers. ${doc "/batteries/editors/"}
        - **Export.** The fleet as sorted N-Triples with a checksum, and SHACL shapes for graph stores. ${doc "/agents/knowledge/"}
        - **Migration.** Move from a single `configuration.nix`, a flake, or Den. ${doc "/migrate/from-configuration-nix/"}

        ## Try it

        ```sh
        nix flake init -t github:vic/yen#one-page-fleet
        ```

        Then read ${link "A fleet on one page" "/start/one-page-fleet/"} and the ${link "documentation" "/"}.

        ## Sponsor Development

        Yen is made with love by [vic](https://github.com/vic). Years of work have gone into bringing formal verification
        to reproducible Nix fleets in our agentic era, because correctness matters most here.
        If Yen helps your business, your homelab, your team or your agents, please [sponsor vic](https://dendritic.oeiuwq.com/sponsor).
        Issues and pull requests are welcome: see [CONTRIBUTING.md](CONTRIBUTING.md).
      ''
    ];

  checks =
    {
      result,
      variant,
      eq,
      lib,
      ...
    }:
    let
      inv = (variant "variants/invariant.nix").check;
      p = (variant "variants/ports.nix").reduced.greetings."world:earth".ports;
      cmd = "nix run github:vic/yen?dir=mcp";
    in
    {
      result = eq result.flake (import ./result.nix);
      invariant = {
        violations = eq (inv.violations) ([
          [
            "bad"
            "no-desktop-on-servers"
            "fleet:main/host:web"
          ]
        ]);
        whyNot-holds = eq (inv.whyNot (inv.bad.no-desktop-on-servers web)) ([ ]);
        whyNot-candidate = eq (inv.whyNot (inv.bad.no-desktop-on-servers db)) ([
          {
            rule = null;
            reason = "no rule has this head";
          }
        ]);
      };
      ports-errors = eq ((variant "variants/ports.nix").errors) ([ ]);
      region = eq ((variant "variants/region.nix").check.violations) ([
        [
          "bad"
          "db-same-region"
          "fleet:main/region:eu/host:api"
        ]
      ]);
      mcp-run-line = {
        flake = eq (lib.hasInfix cmd (builtins.readFile ../../../mcp/flake.nix)) true;
        skill = eq (lib.hasInfix cmd (builtins.readFile ../../../.claude/skills/yen-mcp/SKILL.md)) true;
      };
      ports = {
        first = eq (p.first) ([
          {
            grafana = 8081;
            loki = 8082;
            prometheus = 8080;
          }
        ]);
        count = eq (p.count) (12);
      };
    };
}
