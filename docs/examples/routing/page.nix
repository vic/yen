{
  title = "Routing and walls";
  description = "An element goes up to the nearest scope that has the sink and where the sink's `at` holds.";
  section = "behavior";
  order = 5;

  body =
    { docs, result, ... }:
    [
      ''
        An [aspect](/behavior/aspects/) doesn't say who receives its elements, the tree does. An element goes to the
        nearest ancestor-or-self [scope](/model/scopes/) that has the [sink](/behavior/sinks/) and where the sink's `at` holds.

        This example has a fleet, two environments, two hosts, a user and a home. First, each kind's sinks:
      ''
      (docs.fileNoted "" "modules/fleet.nix")
      ''
        `(1)` is the fleet's `dns` sink, the fallback receiver. `(2)` is an environment's `dns` sink, whose `at` only
        holds where `public` is true. `(3)` is a host's `os` sink, and `(4)` is a home's `os` sink. The users and homes:
      ''
      (docs.file "modules/instances.nix")
      ''
        And the aspects that give the elements:
      ''
      (docs.fileNoted "" "modules/aspects.nix")
      ''
        `(1)` gives an `os` element at every user and home, and `(2)` gives a `dns` element at every host. Here's what the
        flake gets, and the table explains why each element lands where it does:
      ''
      (docs.value (removeAttrs result.flake [ "checks" ]))
      (docs.table
        [ "Element" "Given at" "Received at" "Why" ]
        [
          [
            "`os`"
            "user `alice`"
            "host `web`"
            "a user has no `os` sink; the host above has one"
          ]
          [
            "`os`"
            "home `bob`"
            "home `bob`"
            "the home has its own `os` sink: ancestor-or-self"
          ]
          [
            "`dns`"
            "host `web`"
            "environment `prod`"
            "`prod` is public, so its `dns` sink holds"
          ]
          [
            "`dns`"
            "host `box`"
            "fleet `main`"
            "`lab` is not public; the next receiver is the fleet"
          ]
        ]
      )
      ''
        The routes, drawn from `result.graph.edges`:
      ''
      (docs.routes result)
      ''
        ## Walls

        A sink with no keys is a wall: it receives elements and passes nothing on. That's how a home under a host keeps
        its packages away from the host:
      ''
      (docs.fileNoted "" "modules/walls.nix")
      ''
        `(1)` is the wall, a home's `packages` sink with no keys. `result.reduced.packages` shows both receivers, and only
        the host gives its packages to the flake:
      ''
      (docs.value result.reduced.packages)
      (docs.note "A sink nobody reads" ''
        A sink nobody reads isn't an error. Nothing happens, and thanks to laziness it costs nothing either.
      '')
    ];

  checks =
    {
      result,
      eq,
      yes,
      no,
      ...
    }:
    {
      lean = eq (builtins.mapAttrs (_: builtins.attrNames) result.flake.checks) {
        aarch64-darwin = [ "yen-lean" ];
        aarch64-linux = [ "yen-lean" ];
        x86_64-linux = [ "yen-lean" ];
      };
      flake = eq (removeAttrs result.flake [ "checks" ]) ({
        dns = {
          fleet = [ "box A" ];
          prod = [ "web A" ];
        };
        os = {
          bob = [ "account bob" ];
          web = [ "account alice" ];
        };
        packages.web = [ "vim for alice" ];
      });
      wall = eq (result.reduced.packages."fleet:main/environment:prod/host:web/home:bob") ([
        "vim for bob"
      ]);
    };
}
