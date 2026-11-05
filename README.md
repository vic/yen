# Nix fleets you can [formally verify](https://yen.oeiuwq.com/query/lean/) before deployment.

<!-- Generated from docs/examples/why/page.nix. Edit there, then run `nix run .#write-files` in docs/. -->

**Yen is a minimal pure-Nix logic language for verifying fleets before deployment**.

It allows you to describe the model of your fleet, in your own terms and the relationships between all your
infra entities. Then you can rule invariants about these relationships that must always hold true.
An invalid fleet is not even part of the flake output, so it is not possible to build or deploy if rules
have been violated. This is important for infrastructures at large in this AI era, where iterations happen 
more rapidly than a human can possibly review.


[Documentation](https://yen.oeiuwq.com/) · [Getting started](https://yen.oeiuwq.com/start/getting-started/) · [A fleet on one page](https://yen.oeiuwq.com/start/one-page-fleet/) · [Verified by Lean](https://yen.oeiuwq.com/query/lean/) · [Reference fleet](https://github.com/vic/yen/tree/main/reference) · [vic/vix@yen](https://github.com/vic/vix/tree/yen) · [Sponsor vic](https://dendritic.oeiuwq.com/sponsor)


> Q: How is this different from having some `assert`s and `throw`s around some conditionals in my Nix code? 
>
> A: Main difference is Yen produces a certificate that can be shipped and validated outside the infra code by [Lean4](https://lean-lang.org).
> If this certificate is reproduced and verified by Lean then it must also be verified by Yen otherwise the fleet is invalid.
> Only a valid fleet can exist as flake outputs. - This question is similar to asking the difference between
> throws at runtime in code, unit-tests, property-testing and formal verification. Yen lands on the last of these,
> since certificates and the fleet model+invariants were produced by Nix as json but can be re-checked without Yen.


## Things you can do with Yen

**Datalog solver on facts that see the whole fleet, not a single hosts.** A rule can talk about hosts, networks, regions, anything **you can describe with Nix**: 
an app and its database must share a region, no two hosts may share an address, every service that stores data has a backup
in a different region. You run `nix flake check`, and it now covers every fleet entity at once. <sup>[docs](https://yen.oeiuwq.com/query/invariants/)</sup>

**Ship certificates as guarantee.** Every Yen verdict carries a certificate, the steps that prove it and can be exported as json.
The Lean4 checker reads the certificate and from its steps builds the cases of each rule from the facts by itself, without trusting Yen's own work.
When it accepts, no rule is broken and none is left undecided. You can run the same check on a verdict file anywhere, in CI
or on your laptop: <sup>[docs](https://yen.oeiuwq.com/query/lean/)</sup>


```sh frame="terminal"
$ nix run github:vic/yen#yen-cert-check -- certificate.json
```

**Agents have guard-rails on critical infrastructure.** An agent proposes a change via Yen MCP and stages a change <sup>[docs](https://yen.oeiuwq.com/agents/stage/)</sup>:
the fleet is not built but the invariants are verified with the change and without it, and the agent sees what would break before a single file is written.
A grant limits how far a change may reach, and a grant can only get narrower. When a change is refused for lack of authority, the
agent does not hunt for a way around it, it goes to the owner with what it wanted and the reason before anything was built.


```sh frame="terminal"
$ nix run github:vic/yen?dir=mcp
```

**Answers about current/hypothetical fleet state and why-not.** Ask why a rule broke and you get the facts that broke it. Ask why it holds and you get what
keeps it from breaking. Errors work the same way: each one is a record with the place, what was expected, what was
found and how to fix it, and a typo comes with a "did you mean". You and your agents read the same records.
<sup>[docs](https://yen.oeiuwq.com/principles/errors/)</sup>.


**Derived and verified configuration values.** 
Yen's Kanren logic substrate <sup>[docs](https://yen.oeiuwq.com/query/ukanren/)</sup> allows configuration to be synthesized (generated) instead of provided statically by a human.
Invariants are key to verifying that machine-generated configs are sound. 
An example could be dynamic vm-guests memory must always be a proportion of their host memory according to client plan, or
find another suitable vm-host for it.


**Deploys in the right order.** Yen sorts your machines into waves, each read is a tracked dependency so Yen knows what depends on what without cycles.  <sup>[docs](https://yen.oeiuwq.com/query/graphs/)</sup>

**Provenance tracking.** A value is never copied nor merged so it preserves info on files that declare it, so two files that disagree give an error
instead of one quietly winning. Settings can still cascade, from a host to its environment, in the order you choose.
<sup>[docs](https://yen.oeiuwq.com/principles/queried-not-merged/)</sup>

**Ready-made parts. Choose as much as fits you.** Batteries, Kits and Clan-like Assemblies cover wireguard, dns, sshd, backups, monitoring, postgres and more. You name
the parts of your fleet, and the battery fills in the values. One aspect can serve NixOS, nix-darwin, home-manager,
nix-on-droid and microvm.nix, and each platform takes the part that is meant for it. Your README, CI workflow,
`flake.nix` and dev shell come from the same fleet data, and CI fails when a committed file drifts from it. A host
gets exactly the secrets that name it, and nothing more. <sup>[docs](https://yen.oeiuwq.com/batteries/)</sup>

**Room to move in.** You can bring your existing single `configuration.nix`, a flake, or a Den setup, and build the same systems
with the rules in place. <sup>[docs](https://yen.oeiuwq.com/migrate/from-configuration-nix/)</sup>.


## Try it

Start from a complete fleet on one page, then follow the guide that walks through it:


```sh frame="terminal"
$ nix flake init -t github:vic/yen#one-page-fleet
```

Then read [A fleet on one page](https://yen.oeiuwq.com/start/one-page-fleet/) and the [documentation](https://yen.oeiuwq.com/).

## Sponsor Development

Yen is made with love by [vic](https://github.com/vic). Years of work have gone into bringing formal verification to
reproducible Nix fleets in our agentic era, because correctness matters most here. If Yen helps your business, your
homelab, your team or your agents, please [sponsor vic](https://dendritic.oeiuwq.com/sponsor). Issues and pull
requests are welcome: see [CONTRIBUTING.md](CONTRIBUTING.md).

