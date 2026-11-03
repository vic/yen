# Yen: Nix fleets you can [formally verify](https://yen.oeiuwq.com/query/lean/) before deployment.

<!-- Generated from docs/examples/why/page.nix. Edit there, then run `nix run .#write-files` in docs/. -->


**Yen is a minimal pure-Nix language for fleets you can verify before you deploy them.** It has no dependencies
and no nixpkgs module system. You describe your fleet as terms <sup>[docs](https://yen.oeiuwq.com/model/kinds-fields/)</sup> and the
relationships between them <sup>[docs](https://yen.oeiuwq.com/model/scopes/)</sup>, and you write the rules that must hold across it <sup>[docs](https://yen.oeiuwq.com/query/invariants/)</sup>.
Yen checks every rule before anything is built, and a checker proved correct in [Lean](https://lean-lang.org)
checks Yen's answer again.

[Documentation](https://yen.oeiuwq.com/) · [Getting started](https://yen.oeiuwq.com/start/getting-started/) · [A fleet on one page](https://yen.oeiuwq.com/start/one-page-fleet/) · [Verified by Lean](https://yen.oeiuwq.com/query/lean/) · [Reference template](https://github.com/vic/yen/tree/main/templates/reference) · [vic/vix@yen](https://github.com/vic/vix/tree/yen) · [Sponsor vic](https://dendritic.oeiuwq.com/sponsor)

## Your fleet model, formally verified

A wrong config is cheap to write and expensive to deploy. Two hosts get the same address. A database ends up in
another region than its app. A desktop lands on a server. Evaluation does not see these mistakes: each host is
valid alone, and the mistake is between them. Reviews catch some. An AI agent that writes your Nix makes them
faster than a person can review.

With Yen, you write these rules once, for the whole fleet. Yen turns your fleet into facts and decides each rule
on them before anything is built. A fleet that breaks a rule builds nothing. Yen names the hosts that break it,
and tells you why.

You do not have to trust Yen for this. Each verdict comes with a certificate: the steps that prove it. A second
checker reads the certificate outside Nix. It is written in Lean, and Lean proves it correct. It does not trust
Yen's own work: it builds the cases of each rule from the facts itself. When it accepts, no rule is broken, and
no rule is left undecided.

What you get:

- **A flake check, always on.** A flake from `yen.lib.mkFlake` with `inputs.nixpkgs` has
  `checks.<system>.yen-lean`. `nix flake check` runs the Lean checker on every change. It fails when a rule
  breaks, when a rule is left undecided, when the proof does not check, or when the fleet has an error. For a
  flake you write by hand, add the [Lean battery](https://yen.oeiuwq.com/batteries/lean/).
- **In CI.** The [reference template](https://yen.oeiuwq.com/start/templates/) runs the same check as a job of its generated
  `ci.json`.
- **A command.** `nix run github:vic/yen#yen-cert-check -- verdict.json` checks a verdict anywhere, in CI or on
  your laptop.
- **A tool for agents.** The MCP server (`nix run github:vic/yen#yen-mcp`) gives an agent `yen_verify`. The agent
  reports the fleet good only when Lean agrees.
- **Changes checked before they land.** An agent stages a change with `yen_stage`. Lean checks the fleet with the
  change, before any file is written, and names the rules the change can reach. Lean proves that the rest of the
  fleet stays as it was.
- **Deploy waves you can trust.** Yen orders your machines into deploy waves, each after what it depends on.
  Lean checks the order, and proves the dependencies have no cycle.
- **Facts checked too.** Before reading a rule, Lean checks that the facts make sense: every name points to a
  real part of the fleet, and nothing is its own parent.
- **Answers with reasons.** For each broken rule, Yen gives the facts that break it. For a rule that holds, it
  gives what stops it from breaking.

What to expect:

- Yen verifies your fleet **model**: the hosts, their fields, their aspects and the links between them. It does
  not verify what a built system does when it runs.
- Yen proves the rules you write. It does not find the rules you forgot. Write the mistakes you fear as rules.
- Nix turns your files into facts, and the checker trusts that step. A rule that calls a check written as a Nix
  function cannot be decided by Lean. Such a fleet gets no `yen-lean` check, and the checker refuses its verdict
  when you run it by hand.
- A fleet with a broken rule builds nothing. Its flake has only `invalid-flake-errors` and the Lean check, which
  fails and names the broken rules. You fix the fleet or the rule first.

<details>
<summary>A first Yen flake</summary>

## Yen Flake example

Yen is inspired by [Cycle.js](https://cycle.js.org) `source->sink` value propagation and built on four concepts:
**kinds**, **scopes**, **[aspects](https://yen.oeiuwq.com/behavior/aspects/)** and **[sinks](https://yen.oeiuwq.com/behavior/sinks/)**.
The Yen kernel knows nothing about NixOS. It can describe fleets over any configuration domain: NixOS, nix-darwin,
home-manager, clusters, terraform, k8s, or anything else you can model as Nix values.

- **Kinds**: the nouns of the things in your fleet, and their typed fields.
- **Scopes**: how kinds nest inside each other. `.spawns.` builds the nested cycles from your data: a user under each host.
- **Aspects**: reactive behavior. `.at` sets a predicate that must hold for the behavior to be active: a kind, an instance of a kind, another aspect, or any custom predicate.
- **Sinks**: data channels. A configuration element goes up to the nearest scope that collects a sink, and that scope decides how to [reduce](https://yen.oeiuwq.com/behavior/sinks/) all the contributions.

Yen is built only on Nix `builtins`. This is the most basic NixOS host, the whole `minimal` template
(`nix flake init -t github:vic/yen#minimal`). The flake takes the modules of a directory:



```nix title="templates/minimal/flake.nix"
{
  # build: nixos-rebuild build --flake .#laptop
  description = "One NixOS host";

  outputs =
    inputs:
    inputs.yen.lib.mkFlake {
      inherit inputs;
      inherit (inputs.nixpkgs) lib;
    } (inputs.import-tree ./modules);

  inputs = {
    yen.url = "github:vic/yen";
    import-tree.url = "github:denful/import-tree";
    nixpkgs.url = "https://nixos.org/channels/nixos-25.05/nixexprs.tar.xz";
  };
}
```


The fleet is the root, and its `out` sink is the flake. A host builds NixOS from its `nixos` sink:



```nix title="templates/minimal/modules/fleet.nix"
# The fleet is the root. Its `out` sink is the flake. A host builds NixOS from its `nixos` sink.
{ yen, inputs, ... }:
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.host.sinks.nixos.out =
    { host, nixos, ... }:
    {
      nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem { modules = nixos; };
    };

  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
}
```


The host is data. The aspect `base` is active at every host and gives it one NixOS module:



```nix title="templates/minimal/modules/laptop.nix"
# The host is data. The aspect is active at every host and gives it one NixOS module.
{ yen, ... }:
{
  yen.host.laptop = { };

  yen.aspects.base = {
    at = yen.kinds.host;
    nixos =
      { host, ... }:
      {
        networking.hostName = host.name;
        nixpkgs.hostPlatform = "x86_64-linux";
        # placeholder: change fileSystems and boot for your hardware (see your hardware-configuration.nix)
        boot.loader.grub.device = "nodev";
        fileSystems."/" = {
          device = "/dev/disk/by-label/nixos";
          fsType = "ext4";
        };
        system.stateVersion = "25.05";
      };
  };
}
```


Yen imposes no domain language: `fleet`, `host` and `nixos` are words this fleet chose. The
[templates](https://yen.oeiuwq.com/start/templates/) page lists the other templates.

</details>

The rest of this page goes deeper. Open the sections you need.


<details>
<summary>How Yen works</summary>

## The Cycle model

Yen is designed around [Cycle.js](https://cycle.js.org) and other functional reactive programming principles.
As in Cycle, an aspect <sup>[docs](https://yen.oeiuwq.com/behavior/aspects/)</sup> is a cycle <sup>[docs](https://yen.oeiuwq.com/behavior/cycle/)</sup> function `sources -> sinks`. It sends requests through its `sinks` to its parent cycles
to observe the world, and it gets their answers back through `sources`. A yen module <sup>[docs](https://yen.oeiuwq.com/principles/modules/)</sup> follows the same model: its args are
`sources`, and every key it gives, other than `imports` and `yen`, is a module sink that any module can read.

For example, a user aspect can ask which host it lives on, or whether a service is enabled somewhere else in the fleet.
Most of the time, aspects are simple and look like plain Nix configurations. They need no knowledge of the underlying query model.


## Design Principles

Unlike the nixpkgs module system, where a type's `check` and `merge` are part of the same definition, Yen keeps data validation
separate from the `reduce` (merge) strategy. Each sink boundary defines how data is collected or transformed. Data is queried
instead of being merged into one global `config` attribute.

Yen treats errors as data. Since every relationship and read between kinds is traceable, Yen can build a dependency graph
showing what reads from what, and where the data comes from.

From your definitions, Yen derives logic facts and relationships. You use them with logic variables to state invariants
that must hold across the parts of your fleet before it can even be built. Think of them as formal constraints over
services or fleet members.

</details>

<details>
<summary>Rules, reasons and values</summary>

## Two Logic Languages

Yen ships two pure-Nix logic languages to help you deploy in waves: well-founded models with proofs, why-not explanations,
and values synthesized under constraints <sup>[docs](https://yen.oeiuwq.com/query/queries/)</sup>.

µKanren-style logic programs let you synthesize configurations from constraints. For example, allocate a free port,
or compute a VM's memory so it takes only a percentage of its host.

Datalog facts describe invariants about your fleet. For example, you can state that a web server and its database
must be in the same region or environment.



```nix title="variants/region.nix"
# `facts.host` and `host.region` were derived here by Yen,
# it follows your own domain definitions.
{ yen, ... }:
let
  inherit (yen.lib) maybe same;
  inherit (yen.facts) host;
in
{
  yen.fleet.main = { };
  yen.kinds.fleet.spawns.region = _: yen.region;
  yen.kinds.region.spawns.host =
    s:
    builtins.removeAttrs yen.host (
      builtins.filter (n: !same yen.host.${n}.region s) (builtins.attrNames yen.host)
    );
  yen.kinds.host.fields = {
    region = yen.kinds.region;
    db = maybe yen.kinds.host;
  };

  yen.region.eu = { };
  yen.region.us = { };
  yen.host.db.region = yen.region.us;
  yen.host.api = {
    region = yen.region.eu;
    db = yen.host.db;
  };

  yen.invariants.db-same-region =
    {
      H,
      D,
      R,
    }:
    {
      bad = H;
      pos = [
        (host.db H D)
        (host.region H R)
      ]; # H uses D as its database, and lives in region R
      neg = [ (host.region D R) ]; # and D does not
    };
}
```


Fields, aspects and variables are references, not strings: a typo is an evaluation error. An `api` host in region `eu`
that points at a database in `us` gives `[ "bad" "db-same-region" "fleet:main/region:eu/host:api" ]`, and the fleet
builds nothing until it is fixed.

## Answers come with a reason

Logic questions about your fleet get answers you can read. `result.check.why` gives the rules that make a violation
true. `result.check.whyNot` works the other way. For an atom that is not true, it gives each rule with that head, and
the body atoms that stop it. For an atom that is true, it gives nothing. A question is a literal, by reference:
`result.check.bad.<invariant> host`, with the host an instance (or `{ kind; name; }` from outside the fleet).


```nix title="variants/invariant.nix"
# Two servers and one rule. The desktop runs on `web`, so `web` breaks the rule and `db` does not.
{ yen, ... }:
let
  inherit (yen.facts) host has;
in
{
  yen.fleet.main = { };
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.host.fields.form = yen.lib.is (v: v == "server" || v == "laptop");
  yen.host.web.form = "server";
  yen.host.db.form = "server";
  yen.aspects.desktop.at = yen.host.web;

  # no server runs a desktop
  yen.invariants.no-desktop-on-servers =
    { H }:
    {
      bad = H;
      pos = [
        (host.form H "server")
        (has yen.aspects.desktop H)
      ];
    };
}
```


Here `web` breaks the rule, and `db` does not. The violation for `web`:


```nix title="result"
[
  [
    "bad"
    "no-desktop-on-servers"
    "fleet:main/host:web"
  ]
]
```

`whyNot` for `db` says that no rule has this head. The desktop aspect is only active at `web`, so the rule
is not even a candidate at `db`.


```nix title="result"
[
  {
    reason = "no rule has this head";
    rule = null;
  }
]
```


## Values from constraints

`yen.lib.krn` finds values that fit your constraints, and a relation can run backward.


```nix title="variants/ports.nix"
# µKanren with finite domains: give each app a port in 8080..8083, all different, prometheus before grafana.
{ yen, ... }:
let
  inherit (yen.lib.krn)
    run
    runAll
    freshNamed
    infd
    distinctfd
    ltfd
    eq
    label
    ;
  ports =
    apps: q:
    freshNamed apps (vs: [
      (infd (builtins.attrValues vs) 8080 8083)
      (distinctfd (builtins.attrValues vs))
      (ltfd vs.prometheus vs.grafana)
      (eq q vs)
      (label (builtins.attrValues vs))
    ]);
  lb.scopesOf = yen.host.lb; # a tree request: lb, with its data
in
{
  yen.kinds.world.spawns.host = _: yen.host;
  yen.kinds.host.fields.apps = yen.lib.listOf (yen.lib.is builtins.isString);
  yen.host.lb.apps = [
    "grafana"
    "loki"
    "prometheus"
  ];

  yen.aspects.ports = {
    at = yen.kinds.world;
    cycle =
      { tree, ... }:
      let
        apps = (builtins.head (builtins.head (tree.select lb))).apps;
      in
      {
        tree = [ lb ];
        greetings = [
          {
            ports = {
              first = run 1 (ports apps); # one answer
              count = builtins.length (runAll (ports apps)); # every answer
            };
          }
        ];
      };
  };
}
```

```nix title="result"
{
  count = 12;
  first = [
    {
      grafana = 8081;
      loki = 8082;
      prometheus = 8080;
    }
  ];
}
```

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
`{ ok = true; }`. `result.check.lean` is the verdict for the Lean checker: the rules as written, the facts and the
certificate. <sup>[docs](https://yen.oeiuwq.com/query/lean/)</sup>

</details>

<details>
<summary>Agents and errors</summary>

## Agents as first-class team members

Everything in Yen is expressed as a query, and every answer is JSON-safe data. Agents can propose changes to your
infrastructure, and those changes are verified **before** any file is edited. Changes are staged, checked against
invariants, limited by grants that can only narrow, and written as change programs. An MCP server answers agents and
lets them write only verified changes. <sup>[docs](https://yen.oeiuwq.com/agents/agent-surface/)</sup>

## How agents check a change

An agent works on a Yen fleet through the MCP server in `mcp/`. The skill in `skills/yen-mcp/SKILL.md` gives the
order of calls. The agent reads with `yen_schema` and `yen_check`, asks with `yen_why_not` and `yen_explain`, and stages a
change with `yen_stage` before any file is written. A fleet passes `yen_check` only when `ok` is true, with no violations,
no `incomplete` or `opaque` atoms, and `certified` true. `yen_verify` runs the Lean checker on the same verdict.

From the fleet's working directory, run `nix run github:vic/yen?dir=mcp`. An MCP client starts the same server with
the arguments `[ "run" "github:vic/yen?dir=mcp" ]`.

The agent can show the staged answer to a person, with its violations, its diff and its refusals. A refusal with
`class = "authority"` is not for the agent to fix. The agent tells the owner what it wanted to change, and why.

## Errors are data

Errors are not throws. They are data that agents and humans can inspect, with **hints for fixes**: `code`, `path`,
`got`, `want`, `fix`, and `near` for typos. <sup>[docs](https://yen.oeiuwq.com/principles/errors/)</sup>

</details>

<details>
<summary>Everything Yen does</summary>

## Yen Capabilities

- **Errors you can read.** Yen never throws. A typo gets a "did you mean", and each error gives its place, what was
  expected, and a fix. Agents read the same records. <sup>[docs](https://yen.oeiuwq.com/principles/errors/)</sup>
- **Queries, not merges.** Each value is a query on the files that declare it. Content spread over many files never
  overwrites itself, and two different answers without explicit reduce strategy are an error. <sup>[docs](https://yen.oeiuwq.com/principles/queried-not-merged/)</sup>
- **Rules across machines.** Write a rule once. A fleet that breaks it builds nothing. Each verdict comes with a proof
  that a small checker verifies, and a seal anyone can check again. <sup>[docs](https://yen.oeiuwq.com/query/invariants/)</sup>
- **Verified by Lean.** A checker proved correct in Lean checks each verdict again, as a flake check, a command or
  an agent tool. <sup>[docs](https://yen.oeiuwq.com/query/lean/)</sup> <sup>[docs](https://yen.oeiuwq.com/batteries/lean/)</sup>
- **Changes staged before they land.** `yen.lib.stage` compares the fleet with and without a change. A grant narrows
  what a change may reach, and never widens it. <sup>[docs](https://yen.oeiuwq.com/agents/stage/)</sup>
- **Prove what holds across your fleet.** Graphs for deploy waves, cycles and impact. Datalog with negation. Stored queries you
  name once and ask from Nix, the CLI or an agent. <sup>[docs](https://yen.oeiuwq.com/query/queries/)</sup>
- **Values that solve themselves.** µKanren with finite domains: a free port, guest memory that fits, relations that
  run backward. <sup>[docs](https://yen.oeiuwq.com/query/krn/)</sup>
- **Batteries and kits.** Ready rules in `yen.lib.batteries`, and ready parts in `yen.lib.kits`: wireguard, dns, sshd,
  backups, monitoring, postgres and more. You write the keys, the battery gives the values. <sup>[docs](https://yen.oeiuwq.com/batteries/)</sup>
- **Every platform.** NixOS, nix-darwin, home-manager, nix-on-droid and microvm.nix. One aspect can serve them all.
  <sup>[docs](https://yen.oeiuwq.com/batteries/platforms/)</sup>
- **Generated files.** README, CI workflow, `flake.nix` and dev shell, written from fleet data. <sup>[docs](https://yen.oeiuwq.com/recipes/generated-files/)</sup>
- **Secrets by name.** Secrets are data. A host gets exactly the secrets that name it. <sup>[docs](https://yen.oeiuwq.com/recipes/secrets/)</sup>
- **Time and impact.** See what a host reaches, and which instances are valid at a given date. <sup>[docs](https://yen.oeiuwq.com/agents/history/)</sup>
- **Less to evaluate.** Yen itself is about 1% of a host's evaluation. One nixpkgs per system instead of one per host
  saves about a third, and a check proves every system is the same. <sup>[docs](https://yen.oeiuwq.com/perf/shared-pkgs/)</sup>
- **On par with Den.** Hosts, users, homes, includes, defaults, batteries, guests, roles and secrets. Moving from Den is
  easy. <sup>[docs](https://yen.oeiuwq.com/migrate/from-den/)</sup>
- **Ready for agents.** Every answer is JSON-safe data. An agent asks about your fleet, stages a change, and sees why it
  is refused, before anything is applied. Yen ships an MCP server and a skill for it. <sup>[docs](https://yen.oeiuwq.com/agents/mcp/)</sup>
- **Just Nix.** Yen uses Nix builtins only, with no dependencies. It has no `throw`, no options and no `config`.
- **Assemblies and kits.** Build a machine from members, with layered settings, exports and contracts. Ready-made kits
  cover backups, wifi, remote builders, binary caches, monitoring and postgres. <sup>[docs](https://yen.oeiuwq.com/recipes/assemblies/)</sup> <sup>[docs](https://yen.oeiuwq.com/batteries/kits/)</sup>
- **Roles.** A role is an aspect that applies where a fact holds, so no host file lists its roles. <sup>[docs](https://yen.oeiuwq.com/behavior/predicates/)</sup>
- **Environments and cascades.** Group hosts by where they run, and let settings fall back along an ordered list. <sup>[docs](https://yen.oeiuwq.com/recipes/environments/)</sup>
- **Guests.** Containers and VMs live under their host, and their config goes into the host. <sup>[docs](https://yen.oeiuwq.com/recipes/guests/)</sup>
- **One aspect, many platforms.** A sink forwards its content to a platform's class, so one feature serves NixOS and home-manager. <sup>[docs](https://yen.oeiuwq.com/behavior/forwards/)</sup>
- **Install and deploy.** Disk layouts as data, with install and rebuild apps. <sup>[docs](https://yen.oeiuwq.com/batteries/install/)</sup>
- **Derived network config.** known_hosts, WireGuard peers and Syncthing devices are built from the other hosts. <sup>[docs](https://yen.oeiuwq.com/batteries/kits-network/)</sup>
- **Editors and agent tools.** VS Code, Zed and one shared pool of agent skills and MCP servers. <sup>[docs](https://yen.oeiuwq.com/batteries/editors/)</sup>
- **Export.** The fleet as sorted N-Triples with a checksum, and SHACL shapes for graph stores. <sup>[docs](https://yen.oeiuwq.com/agents/knowledge/)</sup>
- **Migration.** Move from a single `configuration.nix`, a flake, or Den. <sup>[docs](https://yen.oeiuwq.com/migrate/from-configuration-nix/)</sup>

</details>

## Try it

```sh
nix flake init -t github:vic/yen#one-page-fleet
```

Then read [A fleet on one page](https://yen.oeiuwq.com/start/one-page-fleet/) and the [documentation](https://yen.oeiuwq.com/).

## Sponsor Development

Yen is made with love by [vic](https://github.com/vic). Years of work have gone into bringing formal verification
to reproducible Nix fleets in our agentic era, because correctness matters most here.
If Yen helps your business, your homelab, your team or your agents, please [sponsor vic](https://dendritic.oeiuwq.com/sponsor).
Issues and pull requests are welcome: see [CONTRIBUTING.md](CONTRIBUTING.md).

