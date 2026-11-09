{
  title = "About Yen";
  description = "Where Yen comes from, and what it's for: complete fleets that people understand and agents can work on.";
  section = "project";
  order = 1;

  body =
    { docs, ... }:
    [
      ''
        ## The goal

        Yen is for complete fleets: many machines, many people, services that span hosts, environments with their own
        rules. Advanced, complex fleets that a person can still read and understand.

        Yen also treats agents as first-class members of the team that runs the infrastructure. An agent reads the same
        [queries](/query/queries/) a person does: the [schema](/agents/agent-surface/), the errors, why an
        [aspect](/behavior/aspects/) is active. It proposes a change as data, and the fleet [stages](/agents/stage/) it,
        checks the rules across machines, and refuses it with the reason if needed. Nothing reaches a machine unchecked.
      ''
      (docs.cards [
        {
          title = "For people";
          icon = "open-book";
          body = "Four words (see the [glossary](/reference/glossary/)): [kinds](/model/kinds-fields/), [scopes](/model/scopes/), [aspects](/behavior/aspects/), [sinks](/behavior/sinks/). Plain Nix data, and every rule for how content moves is a sink you can read.";
        }
        {
          title = "For agents";
          icon = "rocket";
          body = "Every answer is JSON-safe data. Changes are staged, checked by [invariants](/query/invariants/), and limited by grants (see [Stage a change](/agents/stage/)). An [MCP server](/agents/mcp/) answers.";
        }
      ])
      ''
        ## Lineage

        Yen is the latest step in a line of projects, each one a lesson for the next.
      ''
      (docs.mermaid ''
        flowchart LR
          vix["vic/vix: vic's machines"] --> fa["denful/flake-aspects"]
          fa --> den["denful/den"]
          den --> gen["sini's gen-* libs"]
          den --> exp["vic's experiments: denful/nest, ned, dnzl"]
          gen --> ren["vic/ren"]
          exp --> ren
          ren --> yen["vic/yen"]
      '')
      (docs.table
        [ "Project" "What it gave" ]
        [
          [
            "[vic/vix](https://github.com/vic/vix)"
            "a real fleet: vic's machines, homes and dev environments. Today it runs on Yen."
          ]
          [
            "[denful/flake-aspects](https://github.com/denful/flake-aspects)"
            "aspects, before Den"
          ]
          [
            "[denful/den](https://github.com/denful/den)"
            "aspects: configuration as features that land where they apply"
          ]
          [
            "[sini's gen-* libs](https://github.com/sini/gen)"
            "the libraries of Den's next version (den-hoag on Gen): scopes, graphs, laws"
          ]
          [
            "[denful/nest](https://github.com/denful/nest), [ned](https://github.com/denful/ned), [dnzl](https://github.com/denful/dnzl)"
            "vic's experiments: Nest, CSS-like rules over a tree; Ned, inspired by Cycle.js"
          ]
          [
            "[vic/ren](https://github.com/vic/ren)"
            "the fleet template that Yen's reference fleet models"
          ]
          [
            "vic/yen"
            "[queries instead of merges](/principles/queried-not-merged/), [Cycle.js sources and sinks](/behavior/cycle/), Nix builtins only"
          ]
        ]
      )
      ''
        The [reference fleet](/reference/fleet-map/) shows everything Den, den-hoag and clan can do, plus the advanced
        patterns of real fleets (vix, sini's and others), each with a check. If you'd like to help,
        [Contributing](/project/contributing/) tells you how.
      ''
    ];
}
