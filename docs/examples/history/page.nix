let
  # the host `web`, as a caller outside the fleet names it: its identity
  web = {
    kind = "host";
    name = "web";
  };
  # the fleet without the files that declare aspect `backend`
  withoutBackend =
    engine: module: dir:
    engine.without {
      files = [
        (dir + "/modules/fleet.nix")
        (dir + "/modules/features/backend.nix")
      ];
      path = [
        "aspects"
        "backend"
      ];
      args = { inherit (module) inputs lib yen; };
    };
  summaryOf = w: {
    dropped = map baseNameOf w.dropped;
    dns = w.result.flake.dns or null;
    inherit (w.result) errors;
  };
in
{
  title = "Impact, without, and time";
  description = "What a scope's elements reach, the fleet without the files of one declaration, and instances valid at a date.";
  section = "agents";
  order = 6;

  body =
    {
      docs,
      result,
      engine,
      module,
      dir,
      ...
    }:
    [
      ''
        Before a change, an [agent](/agents/agent-surface/) asks three questions: what else does this touch, what if
        this were gone, and what holds on a given day? The fleet has an environment `prod` and three hosts, and two
        [kinds](/model/kinds-fields/) carry the data and the [sinks](/behavior/sinks/). The marked lines are explained below.
      ''
      (docs.fileNoted "" "modules/fleet.nix")
      (docs.file "modules/features/backend.nix")
      ''
        `(1)` is a fleet field holding the date, because pure evaluation has no clock. `(2)` gives the environments' DNS
        to the flake. `(3)` is the hosts' [spawn](/model/scopes/): an environment only spawns hosts that are valid on
        that date. `(4)` collects an environment's backends and gives them as DNS. `(5)` is the first of two fields,
        `validFrom` and `validTo`, that bound when a host is valid. The `backend` aspect gives each host name to `backends`.

        ## What does this scope reach?

        `result.impact scope { hops; sinks; max; }` follows routed elements from a scope, depth by depth. The scope is a
        ref (`{ kind; name; }` from outside the fleet), each sink is a ref or `{ sink; }`, and each scope it reaches comes
        back as a path of refs. `web` gives a backend to its environment, and the environment gives DNS to the fleet:
      ''
      (docs.value (result.impact web { }))
      ''
        ## What if it were gone?

        `yen.lib.without { files; path; args; }` evaluates the fleet without the files that declare `path`. The whole
        file goes, since there's no hook to remove part of one.
      ''
      (docs.value (summaryOf (withoutBackend engine module dir)))
      ''
        ## Valid time

        Pure evaluation has no clock, so the date is data. An instance with `validFrom` and `validTo` holds at the date
        the caller passes, `yen.lib.validAt date scope`. Here the environment only spawns hosts valid today, so `web-old`
        and `web-next` have no scope:
      ''
      (docs.value (map (s: s.id) result.scopes))
      ''
        ## Transaction time

        `yen.lib.asOf { url; rev; module; }` evaluates the fleet at a git revision. `yen.lib.history { url; revs; module; }`
        lists each revision with the field changes since the one before (`diffData` over `result.data`). The engine's own
        tests run both on this repository, see [tests/agents.nix](https://github.com/vic/yen/blob/main/tests/agents.nix).
      ''
    ];

  checks =
    {
      result,
      engine,
      module,
      dir,
      eq,
      yes,
      no,
      ...
    }:
    {
      impact = eq (map (x: x.scope) (result.impact web { }).reached) ([
        [
          {
            kind = "fleet";
            name = "main";
          }
          {
            kind = "environment";
            name = "prod";
          }
        ]
        [
          {
            kind = "fleet";
            name = "main";
          }
        ]
      ]);
      valid = {
        t1 = yes (builtins.filter (s: s.kind == "host") result.scopes != [ ]);
        t2 = eq (map (s: s.name) (builtins.filter (s: s.kind == "host") result.scopes)) ([ "web" ]);
      };
      without = eq (map baseNameOf (withoutBackend engine module dir).dropped) ([ "backend.nix" ]);
    };
}
