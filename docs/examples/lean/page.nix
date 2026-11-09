{
  title = "Verified by Lean";
  description = "A flake check that builds only when a Lean-proven checker verifies the fleet: no violation true, none undefined.";
  section = "query";
  order = 5;

  body =
    { docs, result, ... }:
    [
      ''
        Every [invariants](/query/invariants/) verdict comes with a [certificate](/reference/glossary/). Yen checks it in Nix,
        and then a checker written and proved in [Lean 4](https://lean-lang.org) checks it again, outside Nix.
        The fleet and the rules are the same as on the [invariants](/query/invariants/) page, as
        [working code](https://github.com/vic/yen/tree/main/docs/examples/lean):
      ''
      (docs.file "modules/fleet.nix")
      (docs.file "modules/invariants.nix")
      ''
        To build the check, add the Lean battery to the flake outputs. `nix flake check` only builds it when the Lean
        checker verifies the verdict:
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
        `lean.verify` is the [Lean battery](/batteries/lean/), and you only need it for a flake you write by hand.
        A flake from `yen.lib.mkFlake` with `inputs.nixpkgs` already has this check as `checks.<system>.yen-lean`, for
        every fleet, clean or not. The docs build this check on this fleet in CI, plus a second one that must be
        rejected: the fleet with mistakes.
      ''
      ''
        The checker reads the rules as you wrote them, with their variables, plus the fleet's facts and the
        certificate. Lean doesn't trust the Yen grounder. It grounds the rules over the facts itself and
        checks that its ground program covers the full one, meaning every instance of a rule whose positive atoms can hold.
        Then it checks the certificate on it. Here's what this fleet gives the checker:
      ''
      (docs.value {
        rules = builtins.length result.check.lean.rules;
        facts = builtins.length result.check.lean.facts;
        proved = builtins.length result.check.lean.certificate.proved;
        refuted = builtins.length result.check.lean.certificate.refuted;
      })
      ''
        This data is `result.check.lean`. Here's what Lean proves, in [lean/](https://github.com/vic/yen/tree/main/lean):

        | Theorem | Says |
        |---|---|
        | `sound` (Certificate.lean) | an accepted certificate is true in every interpretation closed under the well-founded operator of any ground program its rules cover |
        | `not_both` (Certificate.lean) | no atom of an accepted certificate is both proved and refuted |
        | `covers` (Ground.lean) | the program Lean grounds covers the full ground program of the rules and facts |
        | `verify_sound` (Ground.lean) | on a verified verdict, every violation is false in every interpretation closed under the operator |
        | `wfm_fixpoint`, `wfm_least` (Wfm.lean) | the well-founded model, defined in Lean, is the least fixpoint of the well-founded operator |
        | `verify_wfm` (Wfm.lean) | on a verified verdict, every violation is false in the well-founded model of the full program |
        | `shape_no_cycle` (Facts.lean) | on facts that pass the shape check, no scope is its own ancestor |
        | `waves_respect`, `waves_acyclic` (Waves.lean) | verified deploy waves put every dependency in an earlier wave, so the graph has no cycle |
        | `relevance` (Wfm.lean) | two programs with the same rules under a set of atoms give those atoms the same value: a change reaches only its cone |

        CI runs `lean-check` on every change to make sure the proofs compile and none uses `sorry`. The consistency of the
        well-founded model (no atom both true and false) is cited from Van Gelder, Ross and Schlipf 1991, Theorem 5.4.

        The checker also checks the shape of the facts: every id a fact names is a scope, each scope has one kind and
        at most one parent, and every scope reaches the root. Facts that fail are rejected before any rule is read.

        ## Staged changes

        [Stage](/agents/stage/) (`yen.lib.stage`) evaluates the fleet with and without a change. Its `lean` field holds both verdicts, and
        `yen-cert-check --change` reads them: the staged verdict must verify, and the checker names the change's cone,
        meaning the atoms whose rules changed and every atom that reads them. By `relevance`, every atom outside the
        cone keeps its value. The `yen_stage` [MCP tool](/agents/mcp/) answers with this check in `lean`, so before it writes a file an
        agent sees whether Lean accepts the change and which violations it can touch.

        ## Deploy waves

        `lib.graphs.layers` (see [Graphs](/query/graphs/)) orders a graph into waves, where each node comes after everything it depends on.
        The `lean.waves` battery checks the waves in Lean. A cycle leaves nodes out of every wave, so the check fails and names them:
      ''
      (docs.nix ''
        checks.x86_64-linux.waves = yen.lib.batteries.lean.waves {
          inherit pkgs;
          succ = { web = [ "db" ]; db = [ "net" ]; net = [ ]; };
        };
      '')
      ''

        You can run the checker on any fleet without the battery, `nix run github:vic/yen#yen-cert-check -- verdict.json`,
        where `verdict.json` is `builtins.toJSON result.check.lean`. The [MCP server](/agents/mcp/) gives agents the
        same check as the `yen_verify` tool.

        Two things stay trusted: Nix, which evaluates the fleet into facts (Lean only checks their shape), and the Lean
        kernel. Lean doesn't decide an external relation that a Nix function decides (`yen.relations.<name>.holds` or
        `.type`), so the checker exits 2 on it. Lean does decide `lt` and `neq`.

        With the invariants page's mistakes, a desktop on a server and a copied address, the check doesn't build:
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
      no,
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
      # every flake gets the Lean check, but not one whose rules read a relation decided by a Nix function
      auto = {
        t1 = yes (result.flake.checks.x86_64-linux ? yen-lean);
        t2 = yes ((variant "variants/external.nix").check.ok);
        t3 = no ((variant "variants/external.nix").flake ? checks);
      };
    };
}
