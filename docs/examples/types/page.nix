{
  title = "Types and defaults";
  description = "Any value with `check` is a type. `opt`, `maybe` and `derive` add defaults.";
  section = "model";
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
        yen has no type system of its own. A type is any value with `check = value: bool`.
        A `lib.types` value from nixpkgs works, a [kind](/model/kinds-fields/) works (see [Instances and refs](/model/instances-refs/)),
        and a check function can make a type. The `fields` of a kind use types, and some types add defaults.
        This kind has one field of each form:
      ''
      (docs.fileNoted "" "modules/host.nix")
      ''
        Each field has a type. `(1)` is required: it has no default. `(2)` has the default `22`.
        `(3)` is `null` when an instance does not set it. `(4)` computes its default from the instance itself.
        `(5)` makes a type from your own check function. `(6)` is an attrset whose values are strings.
        `(7)` is one of a list of values, and the field sits in a nested path: `settings.kernel.channel`.

        ## The constructors

        The constructors of the types above, with the default of each:
      ''
      (docs.table
        [ "Constructor" "Default" ]
        [
          [
            "`yen.lib.str`, any type"
            "none: the field is required"
          ]
          [
            "`yen.lib.opt type value`"
            "`value`"
          ]
          [
            "`yen.lib.maybe type`"
            "`null`"
          ]
          [
            "`yen.lib.derive type (self: …)`"
            "computed from the instance itself"
          ]
          [
            "`yen.lib.is (v: …)`"
            "none: a type from a check function"
          ]
          [
            "`yen.lib.listOf type`"
            "none: a list whose elements pass the type"
          ]
          [
            "`yen.lib.attrsOf type`"
            "none: an attrset whose values pass the type"
          ]
          [
            "`yen.lib.enum [ … ]`"
            "none: one of the listed values"
          ]
        ]
      )
      (docs.caution "WARNING: use `yen.lib.listOf` and `yen.lib.attrsOf`, not nixpkgs" ''
        nixpkgs `listOf` and `attrsOf` check only the outer shape. Their items are checked in `merge`, which yen
        never calls. So `(nixpkgs.lib.listOf x).check [ "a" ]` is `true` when `x` is an int, and the same holds for
        `attrsOf`. `yen.lib.listOf` and `yen.lib.attrsOf` check every item: the shape when a field reads the value, the
        items in `result.deep`. See
        [the caution on nixpkgs composite types](/principles/modules/#types-anything-with-check).
      '')
      ''
        A field at a path, such as `settings.kernel.channel`, has its own type and default.
        An instance gives only what it needs. The [aspect](/behavior/aspects/) that prints the report is in
        [the example code](https://github.com/vic/yen/tree/main/docs/examples/types/modules/report.nix).
      ''
      (docs.fileNoted "" "modules/hosts.nix")
      ''
        `(1)` sets `vpn` by hand, so the `derive` default of `vpn` does not apply to `db`.
        The read of a field looks at the instance first, then at the default, then checks the value:
      ''
      (docs.value result.flake.report)
      ''
        ## Values that fail a type

        Add this file to the example. It sets a channel that is not in the list, and a label that is not a string:
      ''
      (docs.file "variants/bad-values.nix")
      ''
        A value that fails its type is an error record that names the field. A field reads only the shape of its
        value: a list, an attrset, a function. The parts are checked later, by `result.deep`, after the fleet
        evaluated: so building one host never forces the list elements of another, and a part that throws is an
        error record, not a crash. `nix flake check` fails on both (`checks.<system>.yen-lean`).
        These are the `errors`, then the `deep` records:
      ''
      (docs.value (variant "variants/bad-values.nix").errors)
      (docs.value (variant "variants/bad-values.nix").deep)
      (docs.note "Derived defaults" ''
        `derive` gets the instance as `self`, so a default can read other fields or the instance name.
        An explicit value always wins: `db` sets its own `vpn`.
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
      bad-values = eq (map (e: e.path) (variant "variants/bad-values.nix").errors) ([
        [
          "settings"
          "kernel"
          "channel"
        ]
      ]);
      # the wrong label value is a part of `labels`: the deep check finds it, with its path
      bad-parts = eq (map (e: e.path) (variant "variants/bad-values.nix").deep) ([
        [
          "labels"
          "owner"
        ]
      ]);
      web = eq (result.flake.report.web) ({
        channel = "lts";
        jump = null;
        labels = { };
        port = 22;
        tags = [ ];
        vpn = "vpn-web";
      });
      db = eq (result.flake.report.db) ({
        channel = "latest";
        jump = null;
        labels.role = "database";
        port = 2222;
        tags = [ ];
        vpn = "vpn-database";
      });
    };
}
