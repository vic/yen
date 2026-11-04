{
  title = "Routing and walls";
  description = "An element goes up to the nearest scope that has the sink and where the sink's `at` holds.";
  section = "behavior";
  order = 5;

  body =
    { docs, result, ... }:
    [
      ''
        An [aspect](/behavior/aspects/) does not say who receives its elements. The tree does. An element goes to the nearest
        ancestor-or-self [scope](/model/scopes/) that has the [sink](/behavior/sinks/), and where the sink's `at` holds.

        This example has a fleet, two environments, two hosts, a user and a home. First the sinks of each kind:
      ''
      (docs.fileNoted "" "modules/fleet.nix")
      ''
        `(1)` is the `dns` sink of the fleet: the fallback receiver. `(2)` is the `dns` sink of an environment.
        Its `at` holds only where `public` is true. `(3)` is the `os` sink of a host.
        `(4)` is the `os` sink of a home. The users and homes:
      ''
      (docs.file "modules/instances.nix")
      ''
        And the aspects that give the elements:
      ''
      (docs.fileNoted "" "modules/aspects.nix")
      ''
        `(1)` gives an `os` element at every user and home. `(2)` gives a `dns` element at every host.
        This is what the flake gets, and the table says why each element lands where it does:
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

        A sink with no keys is a wall. It receives elements and gives nothing on. A home under a host
        can keep its packages away from the host:
      ''
      (docs.fileNoted "" "modules/walls.nix")
      ''
        `(1)` is the wall: the `packages` sink of a home has no keys.
        `result.reduced.packages` shows both receivers. Only the host gives its packages to the flake:
      ''
      (docs.value result.reduced.packages)
      (docs.note "A sink nobody reads" ''
        A sink that nobody reads is not an error. Nothing happens. Laziness means it costs nothing either.
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
