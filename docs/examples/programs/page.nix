let
  # a dry run of the program file p, as an agent runs it
  dryRunOf =
    inputs: dir: p:
    import (dir + "/dry-run.nix") {
      program = p;
      yen = inputs.yen.outPath;
      inherit (inputs) nixpkgs import-tree;
    };
in
{
  title = "Change programs";
  description = "A change as a list of data ops: set, ref, place, new. An agent writes a program, not Nix code.";
  section = "agents";
  order = 3;

  body =
    {
      docs,
      inputs,
      dir,
      ...
    }:
    [
      ''
        Writing Nix is a poor interface for an agent, since it can write anything and a typo is a parse error.
        A change program writes a change as data, a list of ops. This one adds a `cache` host to the fleet from the
        [invariants](/query/invariants/) page and places the `postgres` [aspect](/behavior/aspects/) on it:
      ''
      (docs.file "programs/new-cache.json")
      ''
        Four ops are enough for a fleet change:
      ''
      (docs.table
        [ "Op" "Effect" ]
        [
          [
            "`{ op = \"set\"; path; value; }`"
            "one declaration path gets a value"
          ]
          [
            "`{ op = \"ref\"; path; kind; name; }`"
            "one declaration path gets an instance ref"
          ]
          [
            "`{ op = \"place\"; aspect; kind; name; }`"
            "the [aspect](/behavior/aspects/) is also active at that instance"
          ]
          [
            "`{ op = \"new\"; kind; name; fields; }`"
            "a new instance; a field `{ ref = { kind; name; }; }` is a ref"
          ]
        ]
      )
      ''
        ## Dry run

        An agent runs a program with `dryRun`, and nothing is applied. The fleet is the
        [working example](https://github.com/vic/yen/tree/main/docs/examples/programs) in `modules/`, and the marked
        lines are explained below.
      ''
      (docs.fileNoted "" "dry-run.nix")
      ''
        `(1)` calls `yen.lib.program`'s `dryRun`, `(2)` is the fleet to change (its modules and `lib`), and `(3)` reads
        the program from a JSON file. Here's what the dry run answers for `new-cache.json`:
      ''
      (docs.value (dryRunOf inputs dir "programs/new-cache.json"))
      ''
        ## Checked against the schema

        `validate result prog` checks each op before anything runs: kinds, fields and aspects must exist, and typos get a `near`.
        `dryRun` validates first and only [stages](/agents/stage/) a valid program. This program has a typo in a field
        and another in an aspect:
      ''
      (docs.file "programs/typos.json")
      (docs.value (dryRunOf inputs dir "programs/typos.json"))
      (docs.table
        [ "Function" "Use" ]
        [
          [
            "`validate result prog`"
            "error records, `[ ]` when the program is valid"
          ]
          [
            "`toModule prog`"
            "the program as a Yen module, to import"
          ]
          [
            "`dryRun { base; prog; grant; rejected; }`"
            "validate, then [stage](/agents/stage/)"
          ]
          [
            "`builtins.toJSON prog`"
            "JSON, to store or send"
          ]
        ]
      )
    ];

  checks =
    {
      inputs,
      dir,
      eq,
      yes,
      no,
      ...
    }:
    {
      ok = yes ((dryRunOf inputs dir "programs/new-cache.json").ok);
      typos = eq (map (e: e.near) (dryRunOf inputs dir "programs/typos.json").errors) ([
        [ "addr" ]
        [ "postgres" ]
      ]);
    };
}
