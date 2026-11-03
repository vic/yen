{
  title = "Verified by Lean";
  description = "A flake check that builds only when a Lean-proven checker verifies the fleet: no violation true, none undefined.";
  section = "query";
  order = 5;

  body =
    { docs, result, ... }:
    [
      ''
        Every verdict of [invariants](/query/invariants/) comes with a certificate. Yen checks it in Nix, and a checker
        written and proved in [Lean 4](https://lean-lang.org) checks it again, outside Nix. The fleet and its rules:
      ''
      (docs.file "modules/fleet.nix")
      (docs.file "modules/invariants.nix")
      ''
        The battery `lean.verify` gives a flake check. `nix flake check` builds it only when the Lean checker verifies the
        verdict:
      ''
      (docs.nix ''
        outputs =
          inputs:
          let
            result = inputs.yen.lib.eval {
              imports = [ (inputs.import-tree ./modules) ];
              inherit inputs;
              inherit (inputs.nixpkgs) lib;
            };
          in
          result.flake // {
            checks.x86_64-linux.lean = inputs.yen.lib.batteries.lean.verify {
              pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
              inherit result;
            };
          };
      '')
      ''
        The docs build this check on this fleet in CI, and a second one that must be rejected: the fleet with mistakes.
      ''
      ''
        The checker reads `result.check.lean`: the rules as you wrote them, with their variables, the facts of the
        fleet, and the certificate. Lean does not trust Yen's grounder. It grounds the rules over the facts itself and
        checks that its ground program covers the full one: every instance of a rule whose positive atoms can hold.
        Then it checks the certificate on it. This fleet gives the checker:
      ''
      (docs.value {
        rules = builtins.length result.check.lean.rules;
        facts = builtins.length result.check.lean.facts;
        proved = builtins.length result.check.lean.certificate.proved;
        refuted = builtins.length result.check.lean.certificate.refuted;
      })
      ''
        What Lean proves, in [lean/](https://github.com/vic/yen/tree/main/lean):

        | Theorem | Says |
        |---|---|
        | `sound` (Certificate.lean) | an accepted certificate is true in every interpretation closed under the well-founded operator of any ground program its rules cover |
        | `not_both` (Certificate.lean) | no atom of an accepted certificate is both proved and refuted |
        | `covers` (Ground.lean) | the program Lean grounds covers the full ground program of the rules and facts |
        | `verify_sound` (Ground.lean) | on a verified verdict, every violation is false in the well-founded model of the full program |

        CI runs `lean-check` on every change: the proofs compile, and none uses `sorry`.

        Run the checker on any fleet without the battery: `nix run github:vic/yen#yen-cert-check -- verdict.json`,
        where `verdict.json` is `builtins.toJSON result.check.lean`. The [MCP server](/agents/agent-surface/) gives the
        same check to agents as the tool `yen_verify`.

        What stays trusted: Nix, which evaluates the fleet into facts, and the Lean kernel. An external relation
        decided by a Nix function (`yen.relations.<name>.holds` or `.type`) is not decided by Lean: the checker
        exits 2 on it. `lt` and `neq` are decided by Lean.

        With the mistakes of the invariants page, a desktop on a server and a copied address, the check does not build:
      ''
      (docs.file "variants/mistakes.nix")
      ''
        ```
        rejected: violations not refuted (2 rules, 30 facts, 32 ground rules, 6 proved, 0 refuted):
          ["bad", "no-desktop-on-servers", "fleet:main/host:web"]
          ["bad", "unique-addr", "fleet:main/host:db", "fleet:main/host:spare"]
        ```
      ''
    ];

  checks =
    {
      result,
      variant,
      eq,
      yes,
      ...
    }:
    {
      ok = yes (result.check.ok);
      # the rules as written: their variables reach Lean
      vars = yes (builtins.any (r: builtins.any builtins.isAttrs r.head) result.check.lean.rules);
      sizes =
        eq
          {
            rules = builtins.length result.check.lean.rules;
            facts = builtins.length result.check.lean.facts;
          }
          ({
            rules = 2;
            facts = 23;
          });
      mistakes = eq (builtins.length (variant "variants/mistakes.nix").check.violations) (2);
    };
}
