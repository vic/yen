let
  # the stage of a change of this page's fleet, as `stage.nix` runs it
  stageOf =
    inputs: dir: args:
    import (dir + "/stage.nix") (
      {
        yen = inputs.yen.outPath;
        inherit (inputs) nixpkgs import-tree;
      }
      // args
    );
  # the host `db`, as a caller outside the fleet names it
  db = {
    kind = "host";
    name = "db";
  };
  # what the refusals of a grant say: all outside it, and which scopes they name last
  grantFacts = refused: {
    outside = builtins.all (e: e.code == "outside-grant") refused;
    thinkpad = builtins.elem {
      kind = "host";
      name = "thinkpad";
    } (map (e: builtins.elemAt e.got (builtins.length e.got - 1)) refused);
    db = builtins.elem db (map (e: builtins.elemAt e.got (builtins.length e.got - 1)) refused);
  };
in
{
  title = "Stage a change";
  description = "Evaluate the fleet without and with a change. New errors, new violations, a diff, and refusals with their reason.";
  section = "agents";
  order = 2;

  body =
    {
      docs,
      inputs,
      dir,
      engine,
      ...
    }:
    [
      ''
        Before you apply a change, stage it. Staging evaluates the fleet without and with the change, and nothing is applied.

        The fleet is the one from [Invariants](/query/invariants/). A change is plain data, so an agent can write it as JSON:
      ''
      (docs.file "changes/desktop-on-web.json")
      ''
        This file stages the change, and the marked lines are explained below.
      ''
      (docs.fileNoted "" "stage.nix")
      ''
        `(4)` calls `yen.lib.stage { base; change; rejected; grant; }`, where `base` (`(3)`) is the fleet and `change` (`(5)`) is the JSON file.
        `grant` (`(1)`) says where the change can reach, and `rejected` (`(2)`) lists the changes refused before.
        The result has `ok`, which is true only when nothing new is wrong. Run it:
      ''
      (docs.sh "nix eval --impure --json --file stage.nix --argstr change changes/desktop-on-web.json")
      (docs.value (stageOf inputs dir { change = "changes/desktop-on-web.json"; }))
      ''
        The change makes `desktop` active at the server `web`, which breaks an invariant. The answer has the violation,
        the diff (scopes, routed elements, active aspects) and the change's `sha`.

        ## Grants only narrow

        A grant says where a change can reach. This change puts `postgres` on the `thinkpad`, but the grant only allows the host `db`:
      ''
      (docs.file "changes/postgres-on-thinkpad.json")
      (docs.nix ''
        yen.lib.grant { scopes = [ { kind = "host"; name = "db"; } ]; }
      '')
      ''
        `yen.lib.grant { scopes; sinks ? null; }` gives a grant, by reference. A scope entry is either an instance
        (`yen.host.db`, or `{ kind; name; }` from outside the fleet), covering every scope that holds it and the scopes under them,
        or a path `[ { kind; name; } … ]`, covering that scope and the scopes under it. A sink is a ref or `{ sink; }`. `narrow g h`
        keeps what both allow. No function makes a grant wider, and a scope written as a string covers nothing.

        An element reads other scopes only through its args and cycle `tree` requests, and Yen records each of these reads.
        That's how `stage` knows the scopes a change reaches: the scopes whose reads get a changed value. Yen refuses each
        one the grant doesn't cover, with `class = "authority"`, because no edit by this author can fix it. A scope the
        change doesn't reach isn't refused. Here are this grant's refusals:
      ''
      (docs.value
        (stageOf inputs dir {
          change = "changes/postgres-on-thinkpad.json";
          grant = engine.grant { scopes = [ db ]; };
        }).refused
      )
      ''
        ## Rejected before

        Pass the `sha` of changes refused before in `rejected`, and the same change is refused again, whoever sends it:
      ''
      (docs.value
        (stageOf inputs dir {
          change = "changes/desktop-on-web.json";
          rejected = [ (stageOf inputs dir { change = "changes/desktop-on-web.json"; }).sha ];
        }).refused
      )
      ''
        ## A change from Nix

        `yen.lib.change.set path value` writes the same data from Nix, where one declaration path gets one value.
        This gives the change in `desktop-on-web.json`:
      ''
      (docs.nix ''
        yen.lib.change.set [ "aspects" "desktop" "at" ] [ { kind = "host"; name = "web"; } ]
      '')
      (docs.tip "Safe places for an aspect" ''
        A stored query can stage an aspect on each machine and return where it's safe, and why the others are refused.
        See `safeHostsFor` in the reference fleet's ${
          docs.fleet "modules/agent/synthesis.nix" null "agent/synthesis.nix"
        }.
      '')
    ];

  checks =
    {
      inputs,
      dir,
      engine,
      eq,
      yes,
      no,
      ...
    }:
    {
      # one stage, one comparison
      violation =
        eq
          {
            inherit (stageOf inputs dir { change = "changes/desktop-on-web.json"; }) ok violations;
          }
          {
            ok = false;
            violations = [
              [
                "bad"
                "no-desktop-on-servers"
                "fleet:main/host:web"
              ]
            ];
          };
      clean = yes (stageOf inputs dir { change = "changes/postgres-on-thinkpad.json"; }).ok;
      grant =
        eq
          (grantFacts
            (stageOf inputs dir {
              change = "changes/postgres-on-thinkpad.json";
              grant = engine.grant { scopes = [ db ]; };
            }).refused
          )
          {
            outside = true;
            thinkpad = true;
            db = false;
          };
      rejected = eq (map (e: e.code)
        (stageOf inputs dir {
          change = "changes/desktop-on-web.json";
          rejected = [ (stageOf inputs dir { change = "changes/desktop-on-web.json"; }).sha ];
        }).refused
      ) ([ "rejected" ]);
      change-set = eq (engine.change.set
        [ "aspects" "desktop" "at" ]
        [
          {
            kind = "host";
            name = "web";
          }
        ]
      ) (builtins.fromJSON (builtins.readFile (dir + "/changes/desktop-on-web.json")));
    };
}
