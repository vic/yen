{
  title = "Datalog";
  description = "Rules with negation over fleet data: well-founded models, stable models, proofs and why-not.";
  section = "query";
  order = 3;

  body =
    { docs, result, ... }:
    [
      ''
        Some questions are rules: "a host serves when it runs a web server and is not drained; a host is drained when a host
        it depends on is down." Datalog solves such rules, with negation, over the data of your fleet.
        This page uses [kinds](/model/kinds-fields/), [instances and refs](/model/instances-refs/) and [aspects](/behavior/aspects/).
        The fleet is four hosts. A web host depends on a database host, and `db-2` is in maintenance.
      ''
      (docs.file "modules/fleet.nix")
      ''
        ## The rules

        `yen.lib.datalog` solves ground rules. Each rule is `{ head; pos; neg; }`: the `head` holds when every atom
        of `pos` holds and no atom of `neg` holds. You ground the rules with Nix: one set per host.
        Each atom is a relation called by reference, and each term is an instance. No relation or host is written as a string.
        The marked lines are explained below.
      ''
      (docs.fileNoted "" "modules/policy.nix")
      ''
        `(1)` is the Datalog library. `(2)` is a [tree request](/behavior/cycle/): every host, with its data.
        The rule at `(3)` gives `serves h` when `h` is a web host and not `drained`.
        A host is `drained` when a host it depends on is not `up`.
        The two rules at `(4)` make a choice: exactly one `primary` database, and the policy does not say which.
        At `(5)`, each relation of `yen.relations` is declared with its arity.
        The `serving` aspect at `(6)` runs a [cycle](/behavior/cycle/) at the root kind.

        In an answer, an instance is `{ kind; name; }`. This is the answer of the `serving` aspect:
      ''
      (docs.value result.flake.serving)
      ''
        The library has these functions:
      ''
      (docs.table
        [ "Function" "Answer" ]
        [
          [
            "`wfs rules`"
            "the well-founded model: `{ true; false; undefined; }`. No strata needed."
          ]
          [
            "`stable rules`"
            "every stable model: one per consistent choice"
          ]
          [
            "`why rules model atom`"
            "the rules that prove an atom"
          ]
          [
            "`proof rules model atom`"
            "a proof tree; a positive cycle shows `cycle = true`"
          ]
          [
            "`whyNot rules model atom`"
            "per rule: the `missing` positive atoms and the `blocking` negative ones"
          ]
          [
            "`judge rules a notA`"
            "`supported`, `refuted`, `both`, `neither` or `unknown`"
          ]
          [
            "`facts atoms`"
            "atoms as rules with no body"
          ]
        ]
      )
      ''
        `web-2` does not serve: its database `db-2` is in maintenance, so `web-2` is drained. `whyNot` says so.
        The primary database is undefined in the well-founded model. The stable models list the two choices.
      ''
      (docs.note "Undefined is an answer" ''
        An atom the rules cannot decide is `undefined`, never a guess. When that matters, give an error record for it.
        [Invariants](/query/invariants/) use the same solver, and treat an undefined violation as `incomplete`, never a pass.
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
      s = result.flake.serving;
      # an atom as the answer states it: the relation, then the instance identity
      atom = rel: name: [
        rel
        {
          kind = "host";
          inherit name;
        }
      ];
    in
    {
      serves = eq (s.serves) ([ "web-1" ]);
      choice = {
        t1 = eq (s.choices) ([
          [ "db-1" ]
          [ "db-2" ]
        ]);
        t2 = eq (s.undefined) ([
          (atom "primary" "db-1")
          (atom "primary" "db-2")
        ]);
      };
      blocking = eq ((builtins.head s.whyNot).blocking) ([ (atom "drained" "web-2") ]);
    };
}
