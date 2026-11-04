{
  title = "Kinds and fields";
  description = "A kind is a type of thing. Its fields are the data of each instance.";
  section = "model";
  order = 1;

  body =
    {
      docs,
      result,
      variant,
      ...
    }:
    [
      ''
        A kind is a type of thing, such as a machine or a person. yen has no built-in kinds: you declare each one.
        The `fields` of a kind are the data of each of its instances. This file declares a kind with two fields.
      ''
      (docs.fileNoted "" "modules/host.nix")
      ''
        The kind `host` has two fields. `(1)` is `addr`, a string: `yen.lib.str` is its type. `(2)` is `cores`, an integer.
        [Types](/model/types/) lists the types.

        Now declare some instances. Any file can do this:
      ''
      (docs.fileNoted "" "modules/hosts.nix")
      ''
        An instance is `yen.<kind>.<name>`: `yen.host.web` is the instance `web` of kind `host`.
        `(1)` sets its `addr` and `(2)` sets its `cores`.

        Next, an [aspect](/behavior/aspects/) reads the fields. It gives one line per host to a
        [sink](/behavior/sinks/). The root kind of the example collects these lines.
        You find it in [the example code](https://github.com/vic/yen/tree/main/docs/examples/kinds-fields/modules/fleet.nix).
        The [glossary](/reference/glossary/) defines the words.
      ''
      (docs.fileNoted "" "modules/report.nix")
      ''
        `(1)` says where the aspect is active: at every `host`. `(2)` asks yen for the nearest host, and `(3)` reads its fields.
        The key `report` gives the element to the sink of the same name. This is what the flake gets:
      ''
      (docs.value result.flake.report)
      ''
        ## Fields are strict

        A missing field, an unknown field and a value that fails its type are error records.
        Evaluation does not stop. The read gives `null`, and the `errors` query lists the problem.
        Add this file to the example:
      ''
      (docs.file "variants/typo.nix")
      ''
        `result.errors` now has three records:
      ''
      (docs.value (variant "variants/typo.nix").errors)
      ''
        `near` names the field you probably meant.
      ''
      (docs.value result.schema.kinds.host.fields)
      (docs.tip "Ask the schema" ''
        The value above is part of `result.schema`. It describes every kind as data: fields with their type names, spawns and sinks.
        `result.data` gives every instance. Both print as JSON, for tools and agents.
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
      report = eq (result.flake.report) ({
        db = "10.0.0.2 (16 cores)";
        web = "10.0.0.1 (4 cores)";
      });
      typo-codes = eq (map (e: e.code) (variant "variants/typo.nix").errors) ([
        "missing"
        "unknown-field"
        "check"
      ]);
    };
}
