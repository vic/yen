let
  # what the check says about a fleet: the rules it breaks, and its errors
  verdictOf = r: {
    inherit (r.check) violations;
    errors = map (e: e.code) r.errors;
  };
in
{
  title = "Check a fleet you already have";
  description = "Keep your flake and your hosts as they are. Describe the fleet as data, write the rules, and get one flake check.";
  section = "migrate";
  order = 0;

  body =
    {
      docs,
      result,
      variant,
      ...
    }:
    [
      ''
        You do not have to move your machines to Yen to get its checks. Yen is about the model of your fleet: which hosts
        you have, where they live, and how they relate to each other. That model can sit next to the flake you already
        have, while every host keeps being built by the same `nixosConfigurations` as today. Yen reads the model, decides
        your rules on it, and gives you one flake check. Nothing else in your flake changes.

        I still think you will want to configure your hosts with Yen one day, because then the model and the machines can
        never disagree. But you can start with the check, and move hosts over later, one at a time or never.

        ## The model

        The model is plain data. Each host has an address, a region, and the host it uses as its database. Regions and
        hosts are both part of the fleet, so a host points at its region by reference, and a typo is an error instead of
        a new region nobody meant to create:
      ''
      (docs.file "modules/model.nix")
      ''
        ## The rules

        A rule is a mistake you never want to deploy, written once for the whole fleet. These two are the classic ones
        that each host passes alone: two hosts with the same address, and a database in another region than the host
        that talks to it.
      ''
      (docs.file "modules/rules.nix")
      ''
        ## One output

        The flake adds `checks` and nothing more. Merge it into the outputs you already have:
      ''
      (docs.file "flake.nix")
      ''
        With `inputs.nixpkgs`, the check is `checks.<system>.yen-lean`. It runs the [Lean checker](/query/lean/) on the
        verdict, so it builds only when no rule is broken, no rule is left undecided, and the proof checks. You run it the
        way you run any check, locally or in CI:
      ''
      (docs.sh "nix flake check")
      ''
        This fleet is clean: no violations, and no errors.
      ''
      (docs.value (verdictOf result))
      ''
        ## A plausible mistake

        Someone adds a host `web` by copying `api`, and moves it to `us`. The new host still has the address of `api`, and
        its database is still in `eu`. Both hosts evaluate fine, and both of these would reach production:
      ''
      (docs.file "variants/clone.nix")
      ''
        With this edit, the check fails and names each machine and each rule it breaks:
      ''
      (docs.value (verdictOf (variant "variants/clone.nix")))
      ''
        Yen checks the model you write, not the machines you build. When the two can drift apart, keep the model honest by
        reviewing it with the hosts it describes, or move those hosts to Yen so the model is what builds them. The
        [invariants](/query/invariants/) page has more about rules, and [From a flake](/migrate/from-flake/) shows the move.
      ''
    ];

  checks =
    {
      result,
      flake,
      variant,
      eq,
      ...
    }:
    {
      clean = eq (verdictOf result) {
        violations = [ ];
        errors = [ ];
      };
      # the example's flake has one output, and it is the Lean check
      outputs = eq (builtins.attrNames flake) [ "checks" ];
      lean = eq (flake.checks.x86_64-linux ? yen-lean) true;
      # one edit, two rules broken: `web` keeps the address of `api`, and its database is in another region
      clone = eq (verdictOf (variant "variants/clone.nix")) {
        violations = [
          [
            "bad"
            "db-same-region"
            "fleet:main/host:web"
          ]
          [
            "bad"
            "unique-addr"
            "fleet:main/host:api"
            "fleet:main/host:web"
          ]
        ];
        errors = [ ];
      };
    };
}
