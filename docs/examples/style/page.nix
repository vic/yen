let
  # the flake config of a fleet: the part both versions of this fleet must agree on
  configOf = r: r.flake.config;
in
{
  title = "Style guide";
  description = "Write a fleet that reads well: name each word once, reuse your combinators, keep one let per file, and use refs.";
  section = "principles";
  order = 5;

  body =
    {
      docs,
      result,
      only,
      ...
    }:
    [
      ''
        A fleet is many small [modules](/principles/modules/). Each one is short when it does one job and names
        each value once. This page shows one small fleet in the style the docs and templates use, then the same fleet
        written in the style to avoid. Both give the same configuration, and a check on this page compares them.

        ## Name the words

        A [kind](/model/kinds-fields/) is a word of your fleet. Put the kinds in one file, apart from the data:
      ''
      (docs.fileNoted "" "modules/kinds.nix")
      ''
        `(1)` A host names its environment in its `env` field, so `spawns` does not filter by hand.
        `yen.lib.pointing "env" yen.host` gives the hosts whose `env` field holds the [scope](/model/scopes/), as one
        ref or in a list. `(2)` The field type is the kind itself: the field holds a [ref](/model/instances-refs/),
        never a name. `(3)` Use the [types](/model/types/) of `yen.lib`. A nixpkgs composite type checks only the outer shape.

        ## Name your combinators once

        A value that two files use goes in `yen.helpers`. Any module reads it from its `yen` arg:
      ''
      (docs.fileNoted "" "modules/helpers.nix")
      ''
        `(1)` A [predicate](/behavior/predicates/) built from the combinators `all`, `within` and `below`: a host in
        prod that has a user. Name it once, and every `at` that needs it reads `servesPeople`.
        `(2)` A function that gives a NixOS value. An aspect calls it with its own data.

        ## One `let`, at the top

        Each file has one `let`, before its attributes. A binding that needs a value of an element (a `scope`, a
        `host`, a tree answer) is a function of that value. The attributes below the `let` only assign:
      ''
      (docs.fileNoted "" "modules/aspects.nix")
      ''
        `(1)` Read the helpers. `(2)` A [tree request](/behavior/cycle/) is data, so it is a binding: the cycle asks it
        and selects it by the same name. `(3)` A function of the host and of the request's answer, with a comment that
        says what it gives. `(4)` The cycle only calls it.

        An expensive value (a `nixosSystem`, a stage, a graph) is computed once: pass it as an argument to the
        function that reads it, and do not call the function that makes it twice.

        ## Refs, not names

        The data says which instance it means with a ref, `yen.env.prod`, not with the string `"prod"`. A ref has no
        typo to make: a wrong one is an [error record](/principles/errors/).
      ''
      (docs.file "modules/instances.nix")
      ''
        ## The style to avoid

        Here is the same fleet in one file. It works, and it gives the same configuration:
      ''
      (docs.file "before/fleet.nix")
      (docs.value (configOf (only [ "before/fleet.nix" ])))
      (docs.table
        [ "Avoid" "Use" ]
        [
          [
            "a name as a string: `env = \"prod\"`"
            "a ref: `env = yen.env.prod`, with a field typed by the kind"
          ]
          [
            "a `spawns` that filters by hand"
            "`yen.lib.pointing \"<field>\" yen.<kind>`"
          ]
          [
            "a predicate that walks `parent` by hand"
            "the combinators `all`, `not`, `within` and `below`, named once in `yen.helpers`"
          ]
          [
            "a `let` inside an element, an aspect or a function"
            "one `let` at the top of the file; a function of the value it needs"
          ]
          [
            "a tree request declared inside the cycle"
            "a binding in the top `let`"
          ]
          [
            "`with` and `rec`"
            "name each attribute; let bindings refer to each other without `rec`"
          ]
          [
            "the same value computed in each call"
            "compute it once and pass it as an argument"
          ]
        ]
      )
      (docs.tip "Code in yen itself" ''
        The engine and its libraries follow the same rules, and a few more: see
        [Contributing](/project/contributing/#coding-standards).
      '')
    ];

  checks =
    {
      result,
      only,
      eq,
      ...
    }:
    {
      no-errors = eq result.errors [ ];
      # the style changes nothing: both versions give the same configuration
      same-config = eq (configOf (only [ "before/fleet.nix" ])) (configOf result);
      # but only the house style holds refs: the data states the environment as kind:name
      refs = eq result.data.host.web.env "env:prod";
      before-strings = eq (only [ "before/fleet.nix" ]).data.host.web.env "prod";
      # ssh only where `servesPeople` holds: web is in prod and has a user; db has none; box is in lab
      ssh =
        eq (builtins.filter (h: (configOf result).${h} ? services) (builtins.attrNames (configOf result)))
          [
            "web"
          ];
    };
}
