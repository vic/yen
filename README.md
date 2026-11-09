# Nix fleets you can [formally verify](https://yen.oeiuwq.com/query/lean/) before deployment.

<!-- Generated from docs/examples/why/page.nix. Edit there, then run `nix run .#write-files` in docs/. -->

**Yen is a small logic language, written in pure Nix, that checks your fleet before you deploy it.**

You describe your fleet in your own words: the hosts, networks, regions and services, and how they relate to
each other. Then you write the rules those relations must always follow. When a rule breaks, the fleet is left out
of your flake outputs, so there is nothing to build or deploy. That matters more every day, now that changes (many
of them from AI agents) arrive faster than anyone can review them.


[Documentation](https://yen.oeiuwq.com/) · [Getting started](https://yen.oeiuwq.com/start/getting-started/) · [A fleet on one page](https://yen.oeiuwq.com/start/one-page-fleet/) · [Verified by Lean](https://yen.oeiuwq.com/query/lean/) · [Reference fleet](https://github.com/vic/yen/tree/main/reference) · [vic/vix@yen](https://github.com/vic/vix/tree/yen) · [Sponsor vic](https://dendritic.oeiuwq.com/sponsor)


> **How is this different from a few `assert`s and `throw`s in my Nix code?**
>
> Yen gives you a certificate. Nix writes the fleet model, its rules and the proof of each verdict as JSON, and
> [Lean4](https://lean-lang.org) can check that file on its own, far from your infra code and without Yen. Lean and
> Yen have to agree, and only a fleet they both accept exists as a flake output. It is the same step you take
> from runtime errors to unit tests, to property tests, to formal verification: Yen lives at the last one.


## Things you can do with Yen

**Rules that see the whole fleet, not one host.** Yen has a Datalog solver, so a rule can talk about anything you
can describe in Nix: an app and its database share a region, no two hosts share an address, every service that
stores data has a backup in another region. `nix flake check` then covers every part of your fleet at once.
<sup>[docs](https://yen.oeiuwq.com/query/invariants/)</sup>

**Certificates you can ship.** Every verdict comes with a certificate, the steps that prove it, exported as JSON.
The Lean4 checker rebuilds the cases of each rule from the facts by itself, so it never has to trust Yen. When it
accepts, no rule is broken and none is left undecided. Run it anywhere, in CI or on your laptop: <sup>[docs](https://yen.oeiuwq.com/query/lean/)</sup>


```sh frame="terminal"
$ nix run github:vic/yen#yen-cert-check -- certificate.json
```

**Guard rails for agents on your infrastructure.** Through the Yen MCP server, an agent stages a change
<sup>[docs](https://yen.oeiuwq.com/agents/stage/)</sup>. Nothing is built, but Yen checks the rules with and without the change, so the agent sees
what would break before it writes a single file. A grant limits how far a change may reach, and a grant can only get
narrower. When a change is refused for lack of authority, the agent doesn't look for a way around it: it goes to the
owner with what it wanted and why, before anything is built.


```sh frame="terminal"
$ nix run github:vic/yen?dir=mcp
```

**Answers, including why not.** Ask why a rule broke and you get the facts that broke it. Ask why it holds and you
get what keeps it holding. You can ask about the fleet you have or one you are thinking of. Errors work the same
way: each one is a record with the place, what was expected, what was found and how to fix it, and a typo comes
with a "did you mean". You and your agents read the same records. <sup>[docs](https://yen.oeiuwq.com/principles/errors/)</sup>

**Configuration that is worked out, then checked.** Yen is built on a small Kanren logic core
<sup>[docs](https://yen.oeiuwq.com/query/ukanren/)</sup>, so a value can be found by Yen instead of typed by hand, and the rules make sure each
generated value is sound. For example, a VM guest's memory can always be a share of its host's memory set by the
customer's plan, or else Yen finds another host that fits.

**Deploys in the right order.** Every read is a tracked dependency, so Yen knows what depends on what, with no
cycles, and sorts your machines into deploy waves. <sup>[docs](https://yen.oeiuwq.com/query/graphs/)</sup>

**You know where each value came from.** Values are never copied or merged, so Yen always knows the file that
declared each one, and two files that disagree give an error instead of one quietly winning. Settings can still
cascade, from a host to its environment, in the order you choose. <sup>[docs](https://yen.oeiuwq.com/principles/queried-not-merged/)</sup>

**Ready-made parts, as many as you want.** Batteries, kits and Clan-like assemblies cover wireguard, dns, sshd,
backups, monitoring, postgres and more: you name the parts of your fleet, and the battery fills in the values. One
aspect can serve NixOS, nix-darwin, home-manager, nix-on-droid and microvm.nix, and each platform takes its own
part. Your README, CI workflow, `flake.nix` and dev shell come from the same fleet data, and CI fails when a
committed file drifts from it. A host gets exactly the secrets that name it, nothing more. <sup>[docs](https://yen.oeiuwq.com/batteries/)</sup>

**Bring what you have.** Start from a single `configuration.nix`, a flake or a Den setup, and build the same
systems with the rules in place. <sup>[docs](https://yen.oeiuwq.com/migrate/from-configuration-nix/)</sup>


## Try it

Start from a complete fleet on one page:


```sh frame="terminal"
$ nix flake init -t github:vic/yen#one-page-fleet
```

Then follow [A fleet on one page](https://yen.oeiuwq.com/start/one-page-fleet/), the guide that walks through it, and the
[documentation](https://yen.oeiuwq.com/).

## Sponsor Development

Yen is made with love by [vic](https://github.com/vic). Years of work went into bringing formal verification to
reproducible Nix fleets, because in this agentic era correctness matters most. If Yen helps your business, your
homelab, your team or your agents, please [sponsor vic](https://dendritic.oeiuwq.com/sponsor). Issues and pull
requests are welcome, see [CONTRIBUTING.md](CONTRIBUTING.md).

