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
        `lib.types` from nixpkgs works, a [kind](/model/kinds-fields/) works (see [Instances and refs](/model/instances-refs/)),
        and `yen.lib.is` makes a type from any function.
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
      (docs.fileWith "{13-14}" "modules/host.nix")
      ''
        Fields can nest. `settings.kernel.channel` is one field at a path, with its own type and default.
        An instance gives only what it needs:
      ''
      (docs.file "modules/hosts.nix")
      ''
        The read of a field looks at the instance first, then at the default, then checks the value:
      ''
      (docs.value result.flake.report)
      ''
        A value that fails its type is an error record that names the field. A field reads only the shape of its
        value: a list, an attrset, a function. The parts are checked later, by `result.deep`, after the fleet
        evaluated: so building one host never forces the list elements of another, and a part that throws is an
        error record, not a crash. `nix flake check` fails on both (`checks.<system>.yen-lean`):
      ''
      (docs.file "variants/bad-values.nix")
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
