{
  title = "Graphs";
  description = "Reachability, layers, cycles and paths over fleet data with `yen.lib.graphs`: deploy waves and impact.";
  section = "query";
  order = 2;

  body =
    {
      docs,
      result,
      variant,
      ...
    }:
    [
      ''
        Fleet data is plain Nix, so a question about it is a function. Graph questions are one kind of question:
        which hosts come first, which hosts break when one is down, is there a cycle. Here, hosts depend on hosts:
      ''
      (docs.file "modules/fleet.nix")
      ''
        ## The deploy plan

        The `deploy-plan` aspect asks the graph questions, and the marked lines are explained below.
      ''
      (docs.fileNoted "" "modules/deploy.nix")
      ''
        `(1)` is the graph library, `yen.lib.graphs`, and `(2)` is a [tree request](/behavior/cycle/) for every host with its data.
        `(7)` builds the graph from the hosts and the hosts each one depends on. It's a graph over instances,
        so its answers are refs `{ kind; name; }` and a host is never named by a string.
        `(3)` gives the deploy waves, `(4)` the hosts that break when one host is down, and `(5)` the shortest path between two hosts.
        `(6)` finds the strongly connected components, which the cycle check below uses.
        The aspect is active at the root kind, in a [cycle](/behavior/cycle/).
      ''
      (docs.value result.flake.deploy)
      ''
        ## The library

        Every function sorts, so the order you write the data in never changes an answer.
        Plain functions take `succ`, an attrset from a node to its successors, and `of nodes next` builds a graph over instances.
      ''
      (docs.table
        [ "Function" "Answer" ]
        [
          [
            "`reach succ n`"
            "every node reachable from `n`"
          ]
          [
            "`reachers succ n`"
            "every node that reaches `n`"
          ]
          [
            "`transpose succ`"
            "the edges reversed"
          ]
          [
            "`topo succ`"
            "a topological order, or `{ ok = false; stuck; }` for a cycle"
          ]
          [
            "`layers succ`"
            "waves: each node after its successors"
          ]
          [
            "`sccs succ`, `cycles succ`"
            "strongly connected components, nodes on a cycle"
          ]
          [
            "`shortest succ a b`, `paths succ a b`"
            "the shortest path, all paths"
          ]
          [
            "`of nodes next`"
            "a graph over instances: every function above takes it, and answers with refs"
          ]
          [
            "`fromEdges es`"
            "`succ` from `[ { from; to; } ]`"
          ]
        ]
      )
      ''
        ## The waves as a diagram

        Here are the deploy waves, drawn from the same data:
      ''
      (docs.mermaid (
        builtins.concatStringsSep "\n" (
          [ "flowchart LR" ]
          ++ builtins.concatLists (
            builtins.genList (
              i:
              map (h: "  ${h} --> w${toString i}[\"wave ${toString (i + 1)}\"]") (
                builtins.elemAt result.flake.deploy.waves i
              )
            ) (builtins.length result.flake.deploy.waves)
          )
        )
      ))
      ''
        ## A cycle is an error

        A cycle is data, not a hang: `sccs` finds it, and the aspect gives an error record:
      ''
      (docs.file "variants/cycle.nix")
      (docs.value (map (e: e.error) (variant "variants/cycle.nix").errors))
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
      waves = eq (result.flake.deploy.waves) ([
        [
          "cache"
          "db"
        ]
        [ "api" ]
        [ "web" ]
        [ "lb" ]
      ]);
      impact = eq (result.flake.deploy.impact.db) ([
        "api"
        "lb"
        "web"
      ]);
      cycle = eq (map (e: e.error) (variant "variants/cycle.nix").errors) ([
        "deploy: a dependency cycle: api -> db -> lb -> web"
      ]);
    };
}
