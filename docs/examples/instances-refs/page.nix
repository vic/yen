{
  title = "Instances and refs";
  description = "A kind is a type: a field can hold a ref to another instance. Kinds that nothing spawns are data.";
  section = "model";
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
        A [kind](/model/kinds-fields/) is also a type. This file declares two kinds, and a field of one holds a ref to an instance of the other:
      ''
      (docs.fileNoted "" "modules/kinds.nix")
      ''
        `(1)` declares the kind `environment`, with one field. `(2)` is a field of kind `environment`: it holds a ref to an
        environment instance, never a string. `(3)` is a field that holds a ref to another `host`, or `null`.

        The instances follow. `yen.environment.prod` is the ref that the field takes, never the string `"prod"`.
      ''
      (docs.fileNoted "{6-7}" "modules/instances.nix")
      ''
        `(1)` sets a field to the ref `yen.environment.prod`. `(2)` refs another host.
        Refs are lazy, so two hosts can point at each other. There is no cycle error.

        Now follow the refs. An [aspect](/behavior/aspects/) reads them like an attrset, and `yen.lib.same` compares two instances.
        The [cycle](/behavior/cycle/) key asks for the tree of hosts, and `report` is the element it gives
        to the [sink](/behavior/sinks/) of that name. The root kind that collects `report` is in
        [the example code](https://github.com/vic/yen/tree/main/docs/examples/instances-refs/modules/fleet.nix).
      ''
      (docs.fileNoted "" "modules/report.nix")
      ''
        `(1)` finds the other hosts in the same environment. `(2)` follows a ref and reads a field of the instance it points to.
        `(3)` tests the ref for `null` and reads the name of the host it points to. The aspect gives this:
      ''
      (docs.value result.flake.report)
      ''
        ## Data kinds

        `environment` is a data kind: no kind spawns it. Its instances have no place in the scope tree,
        and refs to them still work. The tree has the fleet and the hosts only:
      ''
      (docs.scopes result)
      ''
        Groups, channels and secrets are good data kinds. [Scopes](/model/scopes/) shows how a kind gets a place in the tree.

        ## A string is not a ref

        A name where a ref goes is an error record, with the fix:
      ''
      (docs.file "variants/string-ref.nix")
      (docs.value (variant "variants/string-ref.nix").errors)
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
      report = eq (result.flake.report.web) ({
        backup = "db";
        fqdn = "web.example.com";
        peers = [ "db" ];
      });
      data-kind = eq (map (s: s.kind) result.graph.scopes) ([
        "fleet"
        "host"
        "host"
        "host"
      ]);
      ref-error = eq (map (e: e.code) (variant "variants/string-ref.nix").errors) ([ "ref" ]);
    };
}
