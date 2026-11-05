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
        **Yen is a minimal pure-Nix logic language for verifying fleets before deployment**.

        It allows you to describe the model of your fleet, in your own terms and the relationships between all your
        infra entities. Then you can rule invariants about these relationships that must always hold true.
        An invalid fleet is not even part of the flake output, so it is not possible to build or deploy if rules
        have been violated. This is important for infrastructures at large in this AI era, where iterations happen 
        more rapidly than a human can possibly review.


        ${link "Documentation" "/"} · ${link "Getting started" "/start/getting-started/"} · ${link "A fleet on one page" "/start/one-page-fleet/"} · ${link "Verified by Lean" "/query/lean/"} · [Reference fleet](https://github.com/vic/yen/tree/main/reference) · [vic/vix@yen](https://github.com/vic/vix/tree/yen) · [Sponsor vic](https://dendritic.oeiuwq.com/sponsor)


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
        in a different region. You run `nix flake check`, and it now covers every fleet entity at once. ${doc "/query/invariants/"}

        **Ship certificates as guarantee.** Every Yen verdict carries a certificate, the steps that prove it and can be exported as json.
        The Lean4 checker reads the certificate and from its steps builds the cases of each rule from the facts by itself, without trusting Yen's own work.
        When it accepts, no rule is broken and none is left undecided. You can run the same check on a verdict file anywhere, in CI
        or on your laptop: ${doc "/query/lean/"}
      ''
      (docs.sh "$ nix run github:vic/yen#yen-cert-check -- certificate.json")
      ''
        **Agents have guard-rails on critical infrastructure.** An agent proposes a change via Yen MCP and stages a change ${doc "/agents/stage/"}:
        the fleet is not built but the invariants are verified with the change and without it, and the agent sees what would break before a single file is written.
        A grant limits how far a change may reach, and a grant can only get narrower. When a change is refused for lack of authority, the
        agent does not hunt for a way around it, it goes to the owner with what it wanted and the reason before anything was built.
      ''
      (docs.sh "$ ${cmd}")
      ''
        **Answers about current/hypothetical fleet state and why-not.** Ask why a rule broke and you get the facts that broke it. Ask why it holds and you get what
        keeps it from breaking. Errors work the same way: each one is a record with the place, what was expected, what was
        found and how to fix it, and a typo comes with a "did you mean". You and your agents read the same records.
        ${doc "/principles/errors/"}.


        **Derived and verified configuration values.** 
        Yen's Kanren logic substrate ${doc "/query/ukanren/"} allows configuration to be synthesized (generated) instead of provided statically by a human.
        Invariants are key to verifying that machine-generated configs are sound. 
        An example could be dynamic vm-guests memory must always be a proportion of their host memory according to client plan, or
        find another suitable vm-host for it.


        **Deploys in the right order.** Yen sorts your machines into waves, each read is a tracked dependency so Yen knows what depends on what without cycles.  ${doc "/query/graphs/"}

        **Provenance tracking.** A value is never copied nor merged so it preserves info on files that declare it, so two files that disagree give an error
        instead of one quietly winning. Settings can still cascade, from a host to its environment, in the order you choose.
        ${doc "/principles/queried-not-merged/"}

        **Ready-made parts. Choose as much as fits you.** Batteries, Kits and Clan-like Assemblies cover wireguard, dns, sshd, backups, monitoring, postgres and more. You name
        the parts of your fleet, and the battery fills in the values. One aspect can serve NixOS, nix-darwin, home-manager,
        nix-on-droid and microvm.nix, and each platform takes the part that is meant for it. Your README, CI workflow,
        `flake.nix` and dev shell come from the same fleet data, and CI fails when a committed file drifts from it. A host
        gets exactly the secrets that name it, and nothing more. ${doc "/batteries/"}

        **Room to move in.** You can bring your existing single `configuration.nix`, a flake, or a Den setup, and build the same systems
        with the rules in place. ${doc "/migrate/from-configuration-nix/"}.


        ## Try it

        Start from a complete fleet on one page, then follow the guide that walks through it:
      ''
      (docs.sh "$ nix flake init -t github:vic/yen#one-page-fleet")
      ''
        Then read ${link "A fleet on one page" "/start/one-page-fleet/"} and the ${link "documentation" "/"}.

        ## Sponsor Development

        Yen is made with love by [vic](https://github.com/vic). Years of work have gone into bringing formal verification to
        reproducible Nix fleets in our agentic era, because correctness matters most here. If Yen helps your business, your
        homelab, your team or your agents, please [sponsor vic](https://dendritic.oeiuwq.com/sponsor). Issues and pull
        requests are welcome: see [CONTRIBUTING.md](CONTRIBUTING.md).
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
