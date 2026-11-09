{
  title = "The cycle form";
  description = "A cycle asks the tree for data and gives 0 to n elements.";
  section = "behavior";
  order = 2;

  body =
    { docs, result, ... }:
    [
      ''
        Each key of an [aspect](/behavior/aspects/) gives one element. To give 0 to n elements, or to ask the tree for
        data, give the aspect a `cycle`. Like in [Cycle.js](https://cycle.js.org), a cycle is a function from sources to
        [sinks](/behavior/sinks/). This one gives one bridge for each of a host's guests. The `host` and `guest` kinds are in
        [the example code](https://github.com/vic/yen/tree/main/docs/examples/cycle/modules/fleet.nix).
      ''
      (docs.fileNoted "" "modules/network.nix")
      ''
        `(1)` is the cycle. Its sources are `tree`, `scope` and one source per sink, and it returns sinks by name plus
        `tree` requests. `(2)` is a request for this scope's children that are guests, and `(3)` sends it to the tree.
        `(4)` reads the answer with `tree.select` and gives one element per guest. The host has two guests, so the cycle
        gives two bridges:
      ''
      (docs.value result.flake.bridges)
      ''
        ## Tree requests

        A request is one question. `tree.select request` gives its one answer, or `null` when nothing answers it or the
        cycle didn't ask it. The request is its own name, so there's no string to mistype: bind it in a `let` and use it
        twice, like `vms` above. The requests:
      ''
      (docs.table
        [ "Request" "Answer" ]
        [
          [
            "`nearest = yen.kinds.environment`"
            "the nearest scope of that kind, or `null`"
          ]
          [
            "`parent = true`"
            "the parent scope, or `null` at a root"
          ]
          [
            "`children = predicate`"
            "the children where the predicate holds"
          ]
          [
            "`scopesOf = instance`"
            "every scope of an instance"
          ]
          [
            "`holds = predicate`"
            "`true` or `false` at this scope"
          ]
          [
            "`instances = yen.kinds.host`"
            "every instance of that kind, with its data"
          ]
          [
            "`graph = true`"
            "the whole fleet: instances with data and the structure queries, for readers of everything like docs and diagrams"
          ]
        ]
      )
      (docs.note "When to use it" ''
        Most aspects never need `cycle`. Reach for it when the number of elements depends on the tree, or when a cycle
        reports its own `errors`.
      '')
      ''
        ## What an element can read

        An element reads its args: its scope, the kinds it asks for, and the values its sinks give. To read another
        instance it asks the tree, and never reads that instance's fields directly. Because Yen knows what every element
        reads, a change is refused only where it actually reaches. Here a host asks for every host and counts the others:
      ''
      (docs.fileNoted "" "modules/reads.nix")
      ''
        `(1)` is the cycle and `(2)` is a request for every host. `(3)` sends it to the tree, and `(4)` reads the answer.
        The fleet has a single host, so there are no peers:
      ''
      (docs.value result.flake.peers)
      ''
        An element that reads another instance's field is refused. This variant does that at `(1)`:
      ''
      (docs.fileNoted "" "variants/read-addr.nix")
      ''
        The error names the fix: "yen.host.server.addr: an aspect reads instance data only through its args: take `host`
        as an arg, or follow a ref field of an arg".
      ''
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
      bridges = eq (result.flake.bridges.server) ([
        "br-ci"
        "br-db"
      ]);
      peers = eq (result.flake.peers.server) 0;
      refused =
        eq
          (builtins.tryEval (
            builtins.deepSeq (removeAttrs (variant "variants/read-addr.nix").flake [ "checks" ]) true
          )).success
          false;
    };
}
