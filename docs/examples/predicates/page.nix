{
  title = "Predicates";
  description = "`at` takes a predicate: a function, a kind, an instance, an aspect, a list, and `all`, `not`, `within`, `below`.";
  section = "behavior";
  order = 3;

  body =
    {
      docs,
      result,
      variant,
      ...
    }:
    [
      ''
        A predicate says at which [scopes](/model/scopes/) an [aspect](/behavior/aspects/) is active; it's the aspect's `at`.
        This example has two hosts and one guest (a VM) on `big`, and each host has the facts `cores` and `gpu`:
      ''
      (docs.fileNoted "" "modules/fleet.nix")
      ''
        `(1)` makes a guest a child of its host. Now the aspects, where each `at` is a predicate of a different form:
      ''
      (docs.fileNoted "" "modules/aspects.nix")
      ''
        `(1)` is a function of the scope, and `(2)` holds where everything in a list holds.
        `(3)` is true where the `builder` aspect isn't active, and `(4)` holds at a scope with an ancestor where `cuda` is active.
        `(5)` holds at a scope with a guest child, and `(6)` holds where anything in the list holds.

        Here's where each aspect is active (the output comes from an `elements` sink in `modules/report.nix`, in
        [the example code](https://github.com/vic/yen/tree/main/docs/examples/predicates/modules/report.nix)):
      ''
      (docs.value result.flake.active)
      ''
        ## The forms

        A predicate is a function `scope: bool`, and a [kind](/model/kinds-fields/) ref, an instance ref, an aspect ref and a list are predicates too.
      ''
      (docs.table
        [ "Predicate" "Holds at a [scope](/model/scopes/) when" ]
        [
          [
            "`s: …`"
            "the function gives `true`"
          ]
          [
            "`yen.kinds.host`"
            "the scope is a host"
          ]
          [
            "`yen.host.web`"
            "the scope is the instance `web`"
          ]
          [
            "`yen.aspects.cuda`"
            "the aspect `cuda` is active there"
          ]
          [
            "`[ p q ]`"
            "any of the list holds"
          ]
          [
            "`all [ p q ]`"
            "all of the list hold"
          ]
          [
            "`not p`"
            "`p` does not hold"
          ]
          [
            "`within p`"
            "`p` holds at a proper ancestor"
          ]
          [
            "`below p`"
            "`p` holds at a child"
          ]
        ]
      )
      ''
        You can ask any predicate at a scope with `yen.lib.holds p scope`. A `spawns` function can use it too, so
        structure can depend on which aspects are active at the parent.

        ## Cycles and mistakes

        Each scope computes each aspect ref once, so aspects that read aspects cost linear time.
        Refs can form cycles, though. This variant has two aspects that each hold where the other doesn't, and it
        also has a string in `at`:
      ''
      (docs.fileNoted "" "variants/cycle.nix")
      ''
        A cycle through `not` has no answer, so the aspects on it aren't active and the `undefined` query lists them.
        A cycle with no `not` is false.

        `(1)` is a value in `at` that isn't a predicate. That's an error record, never a silent `false`.
      ''
      (docs.tabs [
        {
          label = "result.undefined";
          body = docs.value (variant "variants/cycle.nix").undefined;
        }
        {
          label = "result.errors";
          body = docs.value (variant "variants/cycle.nix").errors;
        }
      ])
      (docs.note "Well-founded semantics" ''
        This is the well-founded semantics of logic programs. You never get an arbitrary answer for a cycle;
        you get "undefined", and a query that tells you where.
      '')
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
      active = eq (result.flake.active) ({
        builder = [ "big" ];
        cuda = [ "big" ];
        monitored = [
          "big"
          "small"
        ];
        tiny = [ "small" ];
        vm-host = [ "big" ];
        vm-tools = [ "ci" ];
      });
      undefined = eq (builtins.length (variant "variants/cycle.nix").undefined) (4);
      at-string = eq (map (e: e.code) (variant "variants/cycle.nix").errors) ([ "at" ]);
    };
}
