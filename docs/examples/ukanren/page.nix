{
  title = "uKanren: synthesis with constraints";
  description = "µKanren with finite domains in pure Nix: values that meet your rules, relations that run backward.";
  section = "query";
  order = 7;
  badge = "advanced";

  body =
    { docs, result, ... }:
    [
      ''
        Some values are not written but found: a port no other app uses, memory that fits a host, a database host in the
        right environment. µKanren with constraints finds such values. It has logic variables, unification over attrsets,
        lists and scalars, and goals that run in both directions. The fleet has one host `lb` with three apps:
      ''
      (docs.file "modules/fleet.nix")
      ''
        ## Ports for the apps

        The goal gives each app a port in 8080..8083. All ports differ, and `prometheus` is before `grafana`.
        The marked lines are explained below. The goals come from `yen.lib.uKanren`, and the table at the end of the page lists them.
      ''
      (docs.fileNoted "" "modules/ports.nix")
      ''
        `(1)` takes the goals from the library. `(2)` makes one logic variable for each app.
        `(3)` gives every variable a finite domain of ports. `(4)` makes all ports differ, and `(5)` makes the `prometheus` port
        lower than the `grafana` port. `(6)` unifies the answer `q` with the variables, and `(7)` enumerates what is left.
        `(8)` takes one answer, and `(9)` reads the same relation backward. `(10)` is a search with fuel.
        The aspect is a [cycle](/behavior/cycle/) that asks the tree for `lb`. These are the answers:
      ''
      (docs.value result.flake.ports)
      ''
        `grafana` can never take 8080: `prometheus` must be lower. The same relation, read backward, says so.
      ''
      (docs.table
        [ "Goal" "Meaning" ]
        [
          [
            "`eq u v`, `fresh`, `freshNamed`, `disj`, `conde`, `project`"
            "µKanren: unify, new variables, any of, clauses, read a value"
          ]
          [
            "`neq u v`"
            "`u` and `v` never unify"
          ]
          [
            "`dom x [ … ]`, `infd xs lo hi`"
            "finite domains"
          ]
          [
            "`lefd`, `ltfd`, `plusfd x y z`, `neqfd`, `distinctfd xs`"
            "propagation over domains"
          ]
          [
            "`label xs`"
            "enumerate what is left, smallest domain first"
          ]
          [
            "`cons`, `appendo`, `membero`, `fromList`, `toList`"
            "relational lists"
          ]
          [
            "`facto rows pattern`"
            "a table of facts"
          ]
          [
            "`run n`, `runAll`, `runC n`"
            "answers for `q: goal`, or `{ x; y; }` for `{ x, y, ... }: goal`; `runC` adds the constraints left on fresh variables"
          ]
          [
            "`runFuel n fuel`, `runAllFuel fuel`, `maximize fuel measure`"
            "bounded search: `{ answers; complete; }`"
          ]
        ]
      )
      (docs.caution "A search must stop" ''
        A search with no answer gives `[ ]`: turn that into an error record. A search an agent writes must have fuel:
        `complete = false` means "bounded", never "no answer". `appendo` with two unknown lists enumerates without end.
      '')
      (docs.tip "More" ''
        The reference fleet's ${
          docs.fleet "modules/query/uKanren.nix" null "query/uKanren.nix"
        } also sums guest memory under a host's RAM
        and joins host records to place a database.
      '')
    ];

  checks =
    {
      result,
      eq,
      yes,
      no,
      ...
    }:
    let
      p = result.flake.ports;
    in
    {
      first = eq (p.first) ([
        {
          grafana = 8081;
          loki = 8082;
          prometheus = 8080;
        }
      ]);
      count = eq (p.count) (12);
      backward = eq (p.on8080) ([
        "prometheus"
        "loki"
      ]);
      fuel = no (p.bounded.complete);
    };
}
