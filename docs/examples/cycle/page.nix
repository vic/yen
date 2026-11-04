{
  title = "The cycle form";
  description = "A cycle asks the tree for data and gives 0 to n elements.";
  section = "behavior";
  order = 2;

  body =
    { docs, result, ... }:
    [
      ''
        Each key of an [aspect](/behavior/aspects/) gives one element. For 0 to n elements, or to ask the tree for data, give the aspect a
        `cycle`. As in [Cycle.js](https://cycle.js.org), a cycle is a function from sources to [sinks](/behavior/sinks/).
        This one gives one bridge for each guest of a host. The kinds `host` and `guest` are in
        [the example code](https://github.com/vic/yen/tree/main/docs/examples/cycle/modules/fleet.nix).
      ''
      (docs.fileNoted "" "modules/network.nix")
      ''
        `(1)` is the cycle. Its sources are `tree`, `scope` and one source for each sink. It returns sinks by name, and `tree` requests.
        `(2)` is a request: the children of this scope that are guests. `(3)` sends the request to the tree.
        `(4)` reads the answer, with `tree.select`, and gives one element for each guest.
        The host has two guests, so the cycle gives two bridges:
      ''
      (docs.value result.flake.bridges)
      ''
        ## Tree requests

        A request is one question. `tree.select request` gives its one answer, or `null` when nothing answers it or the
        cycle did not ask it. The request is its own name, so it has no
        string to mistype. Bind it in a `let` and use it twice, as `vms` above. These are the requests:
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
        Most aspects never need `cycle`. Use it when the number of elements depends on the tree, or when a cycle
        reports its own `errors`.
      '')
      ''
        ## What an element can read

        An element reads its args: its scope, the kinds it asks for, and the values its sinks give. To read another
        instance, it asks the tree. It never reads that instance's fields directly. yen knows what every element reads,
        so a change is refused only where it reaches. Here a host asks for every host and counts the other ones:
      ''
      (docs.fileNoted "" "modules/reads.nix")
      ''
        `(1)` is the cycle. `(2)` is a request for every host. `(3)` sends it to the tree, and `(4)` reads the answer.
        The fleet has one host, so it has no peers:
      ''
      (docs.value result.flake.peers)
      ''
        An element that reads a field of another instance is refused. This variant does that at `(1)`:
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
