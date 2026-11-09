let
  # the host `web`, as a caller outside the fleet names it: its identity
  web = {
    kind = "host";
    name = "web";
  };
in
{
  title = "Queries";
  description = "`yen.lib.eval` gives queries, not one value: errors, graph, scopes, active, reduced, facts, and more.";
  section = "query";
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
        Yen answers questions about a fleet, which is a set of [kinds](/model/kinds-fields/), [scopes](/model/scopes/),
        [aspects](/behavior/aspects/) and [sinks](/behavior/sinks/). This small fleet has one host with one user, and
        two aspects give packages to a `packages` sink. The queries below read it.
      ''
      (docs.file "modules/fleet.nix")
      ''
        ## The queries

        `result = (import yen).lib.eval module` gives you a set of queries. Each one is lazy, so you only pay for what you read
        (see [Data is queried, not merged](/principles/queried-not-merged/)).
        `result` exists outside the fleet: in a script, a test, the CLI or an agent. For inside the fleet, see [below](#inside-the-fleet).
        Every answer is plain data that `builtins.toJSON` prints. Here's what each query answers for the fleet above:
      ''
      (docs.table
        [ "Query" "Answer" ]
        [
          [
            "`errors`"
            "`[ { error; from; code; … } ]`, empty when the fleet is valid"
          ]
          [
            "`graph`"
            "`{ scopes; edges; }`: every scope and every routed element, with its `origin`"
          ]
          [
            "`scopes`"
            "the scopes in order"
          ]
          [
            "`active`"
            "aspect, then scope id, then `true` or `false`"
          ]
          [
            "`undefined`"
            "aspects that `at` can't decide (a cycle through `not`)"
          ]
          [
            "`reduced`"
            "sink, then receiver id, then the value"
          ]
          [
            "`flake`"
            "the answer of `yen.flake`"
          ]
          [
            "`data`"
            "every instance's declared fields"
          ]
          [
            "`schema`"
            "every kind, aspect and invariant, as JSON-safe data"
          ]
          [
            "`declaredIn path`"
            "the files that answer a declaration path"
          ]
          [
            "`facts`"
            "the fleet as ground atoms, for Datalog"
          ]
          [
            "`context id { }`"
            "one scope: parent, children, aspects, what it gives and receives"
          ]
          [
            "`check`"
            "the invariants: see [Invariants](/query/invariants/)"
          ]
        ]
      )
      (docs.tabs [
        {
          label = "reduced";
          body = docs.value result.reduced;
        }
        {
          label = "graph.edges";
          body = docs.value result.graph.edges;
        }
        {
          label = "facts";
          body = docs.value result.facts;
        }
      ])
      ''
        ## One scope in context

        `result.context scope { maxEdges; maxAspects; }` is what an agent or a person reads first about a scope. The scope is a ref
        (`{ kind; name; }` from outside the fleet), and the answer names the parent, children, aspects and edges as refs too.
        Each list says how much of the total it shows:
      ''
      (docs.value (result.context web { }))
      ''
        ## Which aspects reach this host?

        Each `graph` edge has an `origin`, the aspect that gave the element. So "which aspects reach `web`" is a filter,
        not a registry: `map (e: e.origin) (filter (e: e.to == "fleet:main/host:web") result.graph.edges)`.
      ''
      (docs.sh ''
        nix eval --impure --file query.nix errors
        nix eval --impure --json --file query.nix graph
        nix eval --impure --expr '(import ./query.nix).context { kind = "host"; name = "web"; } { }'
      '')
      (docs.note "query.nix" ''
        The commands above use a `query.nix` that returns `eval` of your modules. See [Project layout](/start/project-layout/).
      '')
      ''
        ## Inside the fleet

        A module never gets `result`, because the fleet is what `result` is computed from. Instead, an element reads results
        through its [args](/behavior/args/), and a [cycle](/behavior/cycle/) asks the tree for the rest:
      ''
      (docs.table
        [ "To read" "Inside the fleet" ]
        [
          [
            "a sink's reduced value"
            "a sink arg: `{ packages, ... }:` gets the value at the nearest receiver of `packages`"
          ]
          [
            "the nearest scope of a kind"
            "a kind arg: `{ host, ... }:`"
          ]
          [
            "this scope, its parent"
            "`{ scope, ... }:`, then `scope.parent`"
          ]
          [
            "the children where a predicate holds"
            "a tree request in a `cycle`: `children = p`"
          ]
          [
            "whether a predicate holds here"
            "`yen.lib.holds p scope`"
          ]
          [
            "the scopes of an instance"
            "a tree request in a `cycle`: `scopesOf = instance`"
          ]
          [
            "the whole fleet"
            "a tree request in a `cycle`: `graph = true`. `yen.lib.schema` stays direct"
          ]
        ]
      )
      ''
        The `inside` aspect reads four things at each host:
      ''
      (docs.fileNoted "" "variants/inside.nix")
      ''
        `(1)` asks the tree for the users under this host, `(2)` reads the `packages` sink's reduced value,
        `(3)` reads the parent scope, and `(4)` asks whether the `nginx` aspect holds here. Here's what it gives:
      ''
      (docs.value (variant "variants/inside.nix").reduced.out."fleet:main".inside)
      (docs.note "Not inside" ''
        `errors`, `check`, `context`, `explain` and `impact` read the errors, and an element that reads the errors
        could change them, so they exist only on `result`. A stored query gets `result` when it's asked from outside
        (see [Stored queries](/query/stored-queries/)). A [cycle](/behavior/cycle/) also asks the tree with `tree`.
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
      inside = {
        t1 = eq ((variant "variants/inside.nix").reduced.out."fleet:main".inside) ({
          web = {
            nginx = true;
            packages = [
              "git"
              "nginx"
            ];
            parent = "fleet:main";
            users = [ "ana" ];
          };
        });
        t2 = eq ((variant "variants/inside.nix").errors) ([ ]);
      };
      reduced = eq (result.reduced.packages."fleet:main/host:web") ([
        "git"
        "nginx"
      ]);
      origins =
        eq
          (builtins.sort builtins.lessThan (
            map (e: e.origin) (builtins.filter (e: e.to == "fleet:main/host:web") result.graph.edges)
          ))
          ([
            "aspect git"
            "aspect git"
            "aspect nginx"
          ]);
      facts = yes (builtins.elem [ "has" "nginx" "fleet:main/host:web" ] result.facts);
    };
}
