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
        A kind is a type of thing, like a machine or a person. Yen has no built-in kinds, you declare each one yourself.
        A kind's `fields` are the data each of its instances carries. This file declares a kind with two fields.
      ''
      (docs.fileNoted "" "modules/host.nix")
      ''
        The `host` kind has two fields. `(1)` is `addr`, a string, with `yen.lib.str` as its type. `(2)` is `cores`, an
        integer. [Types](/model/types/) lists all the types.

        Now let's declare some instances. Any file can do this:
      ''
      (docs.fileNoted "" "modules/hosts.nix")
      ''
        An instance is `yen.<kind>.<name>`, so `yen.host.web` is the instance `web` of kind `host`. `(1)` sets its `addr`
        and `(2)` sets its `cores`.

        Next, an [aspect](/behavior/aspects/) reads the fields and gives one line per host to a [sink](/behavior/sinks/).
        The example's root kind collects these lines, you'll find it in
        [the example code](https://github.com/vic/yen/tree/main/docs/examples/kinds-fields/modules/fleet.nix). If a word
        is new to you, the [glossary](/reference/glossary/) explains it.
      ''
      (docs.fileNoted "" "modules/report.nix")
      ''
        `(1)` says where the aspect is active: at every `host`. `(2)` asks Yen for the nearest host, and `(3)` reads its
        fields. The `report` key gives the element to the sink with the same name. Here's what the flake gets:
      ''
      (docs.value result.flake.report)
      ''
        ## Fields are strict

        A missing field, an unknown field or a value that fails its type each give an error record. Evaluation keeps
        going: the read gives `null`, and the `errors` query lists the problem. Add this file to the example:
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
        The value above is part of `result.schema`, which describes every kind as data: fields with their type names,
        spawns and sinks. `result.data` gives every instance. Both print as JSON, for tools and agents.
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
