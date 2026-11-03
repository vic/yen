{
  title = "Lean verification battery";
  description = "lean.verify: a flake check that builds only when the Lean-proven checker verifies the fleet's verdict.";
  section = "batteries";
  route = "batteries/lean";
  order = 10;

  body =
    { docs, ... }:
    [
      ''
        | Battery | Value of | Gives |
        |---|---|---|
        | `lean.verify { pkgs; result; checker ? ; }` | a flake check, next to `yen.lib.eval` | a derivation that builds only when Lean verifies `result` |
        | `lean.waves { pkgs; succ; checker ? ; }` | a flake check | a derivation that builds only when Lean verifies the deploy waves of `succ` (`lib.graphs.layers`) |
        | `lean.systems` | the systems list | the systems of `checks.<system>.yen-lean` |

        `result` is the fleet, `yen.lib.eval module`. The battery writes `result.check.lean` to a file and runs
        `yen-cert-check` on it in the build. The build fails when a violation is true or undefined, when the
        certificate does not check, or when a rule uses an external relation that Lean cannot decide. Its output is
        the checker's message. `checker` defaults to the checker built from `pkgs`. A fleet error fails it too.

        You need it only for a flake you write by hand. A flake from `yen.lib.mkFlake` with `inputs.nixpkgs` has it
        already, as `checks.<system>.yen-lean` on x86_64-linux, aarch64-linux and aarch64-darwin
        (`yen.lib.batteries.lean.systems`), for every fleet, clean or not.
      ''
      (docs.nix ''
        checks.x86_64-linux.lean = yen.lib.batteries.lean.verify {
          pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
          result = yen.lib.eval module;
        };
      '')
      ''
        The same checker, outside a flake check:

        - `nix run github:vic/yen#yen-cert-check -- verdict.json`, with `verdict.json` from `builtins.toJSON result.check.lean`. Exit 0: verified. Exit 1: rejected. Exit 2: input Lean cannot decide.
        - The MCP tool `yen_verify`, from `nix run github:vic/yen#yen-mcp`.
        - `yen-cert-check --change stage.json`, with `stage.json` from `builtins.toJSON (yen.lib.stage { … }).lean`: the
          staged fleet must verify, and the checker names the cone of the change. `yen_stage` runs it for agents.
        - `yen-cert-check --waves waves.json`, with `{ edges; layers; }`: what `lean.waves` runs.

        A full fleet with the battery, and what Lean proves: [Verified by Lean](/query/lean/).
      ''
    ];
}
