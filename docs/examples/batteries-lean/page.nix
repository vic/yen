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
        A fleet can evaluate without errors and still break a rule. A flake check can ask [Lean](/query/lean/) to verify
        the fleet when you build, and the check only builds when Lean agrees. In a flake you write by hand, add it like this:
      ''
      (docs.nix ''
        checks.x86_64-linux.lean = yen.lib.batteries.lean.verify {
          pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
          result = yen.lib.eval module;
        };
      '')
      ''
        `result` is the fleet, `yen.lib.eval module`. The battery writes `result.check.lean` to a file and runs
        `yen-cert-check` on it during the build. The build fails when a violation is true or undefined, when the
        certificate doesn't check, or when a rule uses an external relation Lean can't decide, and its output is the
        checker's message. A fleet error fails it too. `checker` defaults to the checker built from `pkgs`.

        You only need this for a flake you write by hand. A flake from `yen.lib.mkFlake` with `inputs.nixpkgs` already
        has it, as `checks.<system>.yen-lean` on x86_64-linux, aarch64-linux and aarch64-darwin
        (`yen.lib.batteries.lean.systems`), for every fleet, clean or not.

        | Battery | Value of | Gives |
        |---|---|---|
        | `lean.verify { pkgs; result; checker ? ; }` | a flake check, next to `yen.lib.eval` | a derivation that builds only when Lean verifies `result` |
        | `lean.waves { pkgs; succ; checker ? ; }` | a flake check | a derivation that builds only when Lean verifies the deploy waves of `succ` (`lib.graphs.layers`) |
        | `lean.systems` | the systems list | the systems of `checks.<system>.yen-lean` |

        You can also run the same checker outside a flake check:

        - `nix run github:vic/yen#yen-cert-check -- verdict.json`, with `verdict.json` from `builtins.toJSON result.check.lean`. Exit 0 means verified, 1 rejected, and 2 an input Lean can't decide.
        - The MCP tool `yen_verify`, from `nix run github:vic/yen#yen-mcp`. See [MCP](/agents/mcp/).
        - `yen-cert-check --change stage.json`, with `stage.json` from `builtins.toJSON (yen.lib.stage { … }).lean`. The
          staged fleet must verify, and the checker names the cone of the change. `yen_stage` runs it for agents.
        - `yen-cert-check --waves waves.json`, with `{ edges; layers; }`, which is what `lean.waves` runs.

        For a full fleet using the battery, and what exactly Lean proves, see [Verified by Lean](/query/lean/).
      ''
    ];
}
