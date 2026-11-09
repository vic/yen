{
  title = "Fixpoints and dependencies";
  description = "Like NixOS `config`, a Yen fleet is a fixpoint. Unlike `config`, every dependency is a routed edge you can prove.";
  section = "principles";
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
        In NixOS, `config` is a fixpoint: every module reads the final `config`, and Nix laziness computes each value
        when something reads it. A Yen fleet is a fixpoint too, in two layers:

        - **Declarations.** Every module gets `yen`, which is computed from the declarations of all modules,
          its own included. A module reads any file's data through `yen`, the way a NixOS module reads `config.x`.
        - **Results.** An element reads a [sink](/behavior/sinks/)'s reduced value through an arg, and that value can hold elements
          that read other sinks. Sinks feed [sources](/behavior/cycle/), sources feed sinks, and laziness closes the loop.

        The order of the files and of the definitions never matters.

        ## Each NixOS pattern, in Yen

        This fleet has two hosts, and each sink plays the part of one NixOS option:
      ''
      (docs.fileNoted "" "modules/fleet.nix")
      ''
        At `(1)` there's a fleet sink that every host gives to and every host reads. At `(2)`, `yen.lib.derive` makes a default
        from the instance, like a NixOS default reads `config`. At `(3)` a `reduce` you write picks one value, and at `(4)` the flake
        outputs read a sink too. The [aspects](/behavior/aspects/) give the elements:
      ''
      (docs.fileNoted "" "modules/aspects.nix")
      ''
        At `(1)`, `firewall` reads the `ports` sink, like a NixOS option reads another option. At `(2)`, `at` names an aspect,
        so `tls` is active wherever `web` is. At `(3)` and `(4)` each host gives its address to the fleet, and `peers` reads
        what the other hosts gave. This table maps each pattern to its name in this fleet:
      ''
      (docs.table
        [ "NixOS" "Yen" "Here" ]
        [
          [
            "a list option many modules define"
            "a sink; each aspect gives an element"
            "`ports`"
          ]
          [
            "`mkIf config.services.web.enable`"
            "`at` refers to an aspect"
            "`tls.at = yen.aspects.web`"
          ]
          [
            "an option read from another option"
            "a sink arg"
            "`firewall = { ports, ... }: …`"
          ]
          [
            "a default computed from `config`"
            "`yen.lib.derive`"
            "`fqdn`"
          ]
          [
            "attrsets merged from many modules"
            "`reduce.merge`"
            "`settings`"
          ]
          [
            "`mkForce` and `mkDefault`"
            "a `reduce` that picks by priority"
            "`motd`"
          ]
          [
            "`nodes.<other>.config`"
            "give to a sink above both hosts, read it back"
            "`addrs`, `peers`"
          ]
        ]
      )
      (docs.value result.reduced)
      ''
        ## Dependencies are edges

        In NixOS any module can read any option, so a dependency is a read hidden in a function. Nothing lists it,
        and "what changes if I change this?" has no answer before you evaluate.

        In Yen, an element reads only what reaches its [scope](/model/scopes/): its own scope, the nearest scope of a kind, and its
        receivers' sinks. A value goes from one scope to another only as a [routed](/behavior/routing/) element, and each routed
        element is an edge of the [graph](/query/graphs/), with the aspect that gave it. Here are the edges of the `addrs` sink,
        where `peers` on `a` reads what `b` gave to the fleet:
      ''
      (docs.value (builtins.filter (e: e.sink == "addrs") result.graph.edges))
      ''
        ## Where routing helps

        Because the edges are the dependencies, these questions are [queries](/query/queries/), not a search:

        - `result.impact scope { }`: the scopes a scope's elements reach, by depth. See [History](/agents/history/).
        - `result.explain aspect scope depth`: why an aspect is or isn't active at a scope.
        - A grant limits the scopes and sinks a change can give to. It can check a change because every new
          dependency is a new edge. See [Stage a change](/agents/stage/).
        - Labels: an element carries the trust of the files that declare its aspect. See
          [Agent surface](/agents/agent-surface/).

        Reading any value of any scope would add dependencies that aren't edges, and these answers would miss
        them, so Yen has no such read. To read another host's value, give it to a sink of a scope above both hosts,
        like `addrs` does.

        ## What Yen doesn't do

        NixOS resolves two values for one option with priorities, so `mkForce` wins. Yen never overrides data: two
        different values for one declared leaf are an error, and you keep one. For values that many files give,
        the sink's `reduce` decides, like `motd` does above.
      ''
      (docs.file "variants/override.nix")
      (docs.value (map (e: { inherit (e) code path; }) (variant "variants/override.nix").errors))
      (docs.note "Structure from results" ''
        In NixOS, `imports` can't depend on `config`. In Yen, `spawns` can depend on whether an aspect holds, with
        `yen.lib.holds`. See [Predicates](/behavior/predicates/).
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
    let
      at = sink: host: result.reduced.${sink}."fleet:main/host:${host}";
    in
    {
      aggregate = eq (at "ports" "b") ([ 22 ]);
      mkif = eq (at "firewall" "a") ([
        22
        80
        443
      ]);
      default-from-config = eq ((builtins.head (builtins.filter (s: s.name == "a") result.scopes)).fqdn) (
        "a.lan"
      );
      deep-merge = eq (at "settings" "b") ({
        log = {
          level = "info";
          file = "/var/log/b";
        };
      });
      priority = {
        t1 = eq (at "motd" "a") ("welcome");
        t2 = eq (at "motd" "b") ("maintenance");
      };
      other-node = eq (at "peers" "a") ({ b = "10.0.0.2"; });
      edges = eq (map (e: e.from) (builtins.filter (e: e.sink == "addrs") result.graph.edges)) ([
        "fleet:main/host:a"
        "fleet:main/host:b"
      ]);
      override = eq (map (e: e.code) (variant "variants/override.nix").errors) ([ "two-answers" ]);
    };
}
