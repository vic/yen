{
  title = "Sinks and reduce";
  description = "A sink collects elements and reduces them: list, set, flat, one, merge, elements, or your own function.";
  section = "behavior";
  order = 4;

  body =
    {
      docs,
      result,
      variant,
      ...
    }:
    [
      ''
        A sink on a [kind](/model/kinds-fields/) collects the elements that [aspects](/behavior/aspects/) give, and reduces them to one value.
        This host kind has one sink for each way to reduce. The root kind and the flake are in
        [the example code](https://github.com/vic/yen/tree/main/docs/examples/sinks/modules/fleet.nix).
      ''
      (docs.fileNoted "" "modules/sinks.nix")
      ''
        A sink has a `reduce`. `(2)` and `(3)` also have `of`, which checks each element. `(4)` to `(8)` use another reduce each.
        `(1)` is a function you write. The default `reduce` is `list`. The table lists what each reduce gives:

        ## The reduces
      ''
      (docs.table
        [ "Reduce" "Value" "Error" ]
        [
          [
            "`list` (default)"
            "the elements in [scope](/model/scopes/) order"
            "none"
          ]
          [
            "`set`"
            "the elements without duplicates"
            "none"
          ]
          [
            "`flat`"
            "the elements joined: a list element gives its items; without duplicates"
            "none"
          ]
          [
            "`one`"
            "the single element"
            "0 or 2+ elements"
          ]
          [
            "`merge`"
            "a deep attrset"
            "two different leaves at one path"
          ]
          [
            "`elements`"
            "`[ { from; value; } ]`: each value with the scope that gave it"
            "none"
          ]
          [
            "a function"
            "`[ { from; value; } ] -> { value; errors; }`"
            "the errors you give"
          ]
        ]
      )
      ''
        ## One host, all the reduces

        Two [aspects](/behavior/aspects/) give elements to these sinks:
      ''
      (docs.fileNoted "" "modules/aspects.nix")
      ''
        `(1)` and `(2)` give one element each. `(3)` gives a list element, and `flat` joins its items.
        The host `web` gets the same port and the same packages again: `(4)` is a duplicate that `set` drops,
        and `(5)` has duplicates that `flat` drops. Each sink reduces the elements it received:
      ''
      (docs.value result.flake.web)
      ''
        ## When a reduce fails

        A failed reduce is an error record. The other sinks still work. This variant breaks one rule on each line:
      ''
      (docs.fileNoted "" "variants/conflicts.nix")
      ''
        `(1)` gives a second admin to a `one` sink. `(2)` is not a port, so `of` rejects it. `(3)` is a leaf that
        differs from another one at the same path, and `merge` rejects it. The records:
      ''
      (docs.value (variant "variants/conflicts.nix").errors)
      ''
        ## Your own reduce

        A reduce is any function from `[ { from; value; } ]` to `{ value; errors; }`. Write one when the merge order
        is the point: ranked layers, per-key strategies with provenance, or an export store where a scope can only write
        its own elements. The engine sets `from`. An element cannot say where it comes from, so a scope cannot write for another.
      ''
      (docs.tip "Errors and warnings as data" ''
        A sink such as `warnings` with `reduce = list` holds messages that do not fail the fleet.
        See [Errors as data](/principles/errors/).
      '')
      (docs.caution "Names" ''
        Do not give a sink the name of a field or an arg. A sink `tags` and a field `tags` read as one arg.
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
      reduced = eq (result.flake.web) ({
        admin = "alice";
        groups = [
          "audio"
          "wheel"
        ];
        motd = [
          "welcome"
          "this host serves web"
        ];
        nginx.http = {
          gzip = true;
          servers.www.port = 80;
        };
        owners = [ "host" ];
        packages = [
          "git"
          "curl"
          "nginx"
        ];
        ports = [ 22 ];
      });
      failures = eq (map (e: e.code) (variant "variants/conflicts.nix").errors) ([
        "one"
        "merge"
        "of"
      ]);
    };
}
