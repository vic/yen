let
  site = "https://yen.oeiuwq.com";
  link = text: path: "[${text}](${site}${path})"; # absolute: this page is also the repository README
  doc = path: "<sup>[docs](${site}${path})</sup>"; # a small link after a point, so the prose stays clean
  # the two hosts of variants/invariant.nix, as a caller outside the fleet names them: their identity
  web = {
    kind = "host";
    name = "web";
  };
  db = web // {
    name = "db";
  };
  whyNotAt = h: inv: inv.whyNot (inv.bad.no-desktop-on-servers h);
  invariantAnswers = inv: {
    inherit (inv) violations;
    holds = whyNotAt web inv;
    candidate = whyNotAt db inv;
  };
  cmd = "nix run github:vic/yen?dir=mcp"; # the run line the mcp flake and the skill both give
in
{
  title = "Why Yen";
  plainTitle = "Nix fleets you can ${link "formally verify" "/query/lean/"} before deployment."; # the README h1
  description = "Nix fleets you can formally verify before deployment.";
  section = "start";
  order = 1;
  alsoAt = "../README.md"; # the repository README: plain markdown only
  readmeOnly = true; # for people who find the project on GitHub; the site starts at its own pages (#56)

  body =
    { docs, ... }:
    [
      ''
        **Yen is a small logic language, written in pure Nix, that checks your fleet before you deploy it.**

        You describe your fleet in your own words: the hosts, networks, regions and services, and how they relate to
        each other. Then you write the rules those relations must always follow. When a rule breaks, the fleet is left out
        of your flake outputs, so there is nothing to build or deploy. That matters more every day, now that changes (many
        of them from AI agents) arrive faster than anyone can review them.


        ${link "Documentation" "/"} · ${link "Getting started" "/start/getting-started/"} · ${link "A fleet on one page" "/start/one-page-fleet/"} · ${link "Verified by Lean" "/query/lean/"} · [Reference fleet](https://github.com/vic/yen/tree/main/reference) · [vic/vix@yen](https://github.com/vic/vix/tree/yen) · [Sponsor vic](https://dendritic.oeiuwq.com/sponsor)


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
        ${doc "/query/invariants/"}

        **Certificates you can ship.** Every verdict comes with a certificate, the steps that prove it, exported as JSON.
        The Lean4 checker rebuilds the cases of each rule from the facts by itself, so it never has to trust Yen. When it
        accepts, no rule is broken and none is left undecided. Run it anywhere, in CI or on your laptop: ${doc "/query/lean/"}
      ''
      (docs.sh "$ nix run github:vic/yen#yen-cert-check -- certificate.json")
      ''
        **Guard rails for agents on your infrastructure.** Through the Yen MCP server, an agent stages a change
        ${doc "/agents/stage/"}. Nothing is built, but Yen checks the rules with and without the change, so the agent sees
        what would break before it writes a single file. A grant limits how far a change may reach, and a grant can only get
        narrower. When a change is refused for lack of authority, the agent doesn't look for a way around it: it goes to the
        owner with what it wanted and why, before anything is built.
      ''
      (docs.sh "$ ${cmd}")
      ''
        **Answers, including why not.** Ask why a rule broke and you get the facts that broke it. Ask why it holds and you
        get what keeps it holding. You can ask about the fleet you have or one you are thinking of. Errors work the same
        way: each one is a record with the place, what was expected, what was found and how to fix it, and a typo comes
        with a "did you mean". You and your agents read the same records. ${doc "/principles/errors/"}

        **Configuration that is worked out, then checked.** Yen is built on a small Kanren logic core
        ${doc "/query/ukanren/"}, so a value can be found by Yen instead of typed by hand, and the rules make sure each
        generated value is sound. For example, a VM guest's memory can always be a share of its host's memory set by the
        customer's plan, or else Yen finds another host that fits.

        **Deploys in the right order.** Every read is a tracked dependency, so Yen knows what depends on what, with no
        cycles, and sorts your machines into deploy waves. ${doc "/query/graphs/"}

        **You know where each value came from.** Values are never copied or merged, so Yen always knows the file that
        declared each one, and two files that disagree give an error instead of one quietly winning. Settings can still
        cascade, from a host to its environment, in the order you choose. ${doc "/principles/queried-not-merged/"}

        **Ready-made parts, as many as you want.** Batteries, kits and Clan-like assemblies cover wireguard, dns, sshd,
        backups, monitoring, postgres and more: you name the parts of your fleet, and the battery fills in the values. One
        aspect can serve NixOS, nix-darwin, home-manager, nix-on-droid and microvm.nix, and each platform takes its own
        part. Your README, CI workflow, `flake.nix` and dev shell come from the same fleet data, and CI fails when a
        committed file drifts from it. A host gets exactly the secrets that name it, nothing more. ${doc "/batteries/"}

        **Bring what you have.** Start from a single `configuration.nix`, a flake or a Den setup, and build the same
        systems with the rules in place. ${doc "/migrate/from-configuration-nix/"}


        ## Try it

        Start from a complete fleet on one page:
      ''
      (docs.sh "$ nix flake init -t github:vic/yen#one-page-fleet")
      ''
        Then follow ${link "A fleet on one page" "/start/one-page-fleet/"}, the guide that walks through it, and the
        ${link "documentation" "/"}.

        ## Sponsor Development

        Yen is made with love by [vic](https://github.com/vic). Years of work went into bringing formal verification to
        reproducible Nix fleets, because in this agentic era correctness matters most. If Yen helps your business, your
        homelab, your team or your agents, please [sponsor vic](https://dendritic.oeiuwq.com/sponsor). Issues and pull
        requests are welcome, see [CONTRIBUTING.md](CONTRIBUTING.md).
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
    {
      # the hello flake has no nixpkgs input, so no checks.<system>.yen-lean; the docs harness gives it one
      result = eq (removeAttrs result.flake [ "checks" ]) (import ./result.nix);
      # one eval of the variant: the violation, and why not at web (it holds) and at db (no candidate rule)
      invariant = eq (invariantAnswers (variant "variants/invariant.nix").check) {
        violations = [
          [
            "bad"
            "no-desktop-on-servers"
            "fleet:main/host:web"
          ]
        ];
        holds = [ ];
        candidate = [
          {
            rule = null;
            reason = "no rule has this head";
          }
        ];
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
        skill = eq (lib.hasInfix cmd (builtins.readFile ../../../skills/yen-mcp/SKILL.md)) true;
      };
      ports =
        eq { inherit ((variant "variants/ports.nix").reduced.greetings."world:earth".ports) first count; }
          {
            first = [
              {
                grafana = 8081;
                loki = 8082;
                prometheus = 8080;
              }
            ];
            count = 12;
          };
    };
}
