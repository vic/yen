# The agents oracles of the engine: tests.agents.<test> = { expr; expected; }. Run them: fastest --flake .#tests agents
self:
let
  inherit (self.tests._shared)
    b
    eq
    no
    nofw
    ports
    portsBase
    rung1
    yen
    yes
    ;

  r1stage =
    change: grant:
    yen.stage {
      base = rung1 [ ];
      inherit change grant;
    };
  # a scope by reference, as a caller outside the fleet writes it: its path of identities
  T = {
    kind = "top";
    name = "t";
  };
  hostAt = name: [
    T
    {
      kind = "host";
      inherit name;
    }
  ];
  r1grant = yen.grant { scopes = [ (hostAt "web") ]; };
  # a refused path, joined only to compare it here
  r1outside =
    s:
    b.sort b.lessThan (
      map (e: b.concatStringsSep "/" (map (x: "${x.kind}:${x.name}") e.got)) (
        b.filter (e: e.code == "outside-grant") s.refused
      )
    );

in
{
  stage-ok-and-diff =
    let
      base = {
        imports = [ portsBase ];
      };
      s = yen.stage {
        inherit base;
        change = {
          yen = {
            host.c.port = 443;
            aspects.firewall.at = [
              {
                kind = "host";
                name = "c";
              }
            ];
          };
        };
      };
    in
    {
      ok = yes s.ok;
      added = eq s.diff.scopes.added [ "top:t/host:c" ];
      removed = eq s.diff.scopes.removed [ ];
      sha = yes (b.isString s.sha);
      active = eq s.diff.active.added [ "firewall@top:t/host:c" ];
      render =
        eq
          (yen.stage {
            inherit base;
            change = b.fromJSON s.render;
          }).diff
          s.diff;
    };
  stage-refuses =
    let
      base = {
        imports = [ portsBase ];
      };
      ch = yen.change.set [ "host" "a" "port" ] 23;
      s = yen.stage {
        inherit base;
        change = ch;
      };
      v = yen.stage {
        inherit base;
        change = yen.change.set [ "host" "c" "port" ] 1;
      };
    in
    {
      not-ok = no s.ok;
      two-answers = yes (b.any (e: e.code == "two-answers") s.errors);
      rejected =
        eq
          (b.head
            (yen.stage {
              inherit base;
              change = ch;
              rejected = [ s.sha ];
            }).refused
          ).class
          "authority";
      violation = eq v.violations [ (nofw "top:t/host:c") ];
      violation-errors = eq v.errors [ ];
      violation-not-ok = no v.ok;
    };
  grants-narrow =
    let
      g = yen.grant {
        scopes = [ (hostAt "a") ];
        sinks = [ { sink = "fw"; } ];
      };
      all' = yen.grant { scopes = [ [ T ] ]; };
      e = name: sink: {
        to = hostAt name;
        sink.sink = sink;
      };
      # an instance entry covers every scope whose path holds it
      byInstance = yen.grant { scopes = [ (b.elemAt (hostAt "a") 1) ]; };
    in
    {
      allowed = yes (yen.allowed g (e "a" "fw"));
      other-scope = no (yen.allowed g (e "b" "fw"));
      other-sink = no (yen.allowed g (e "a" "nixos"));
      instance = yes (yen.allowed byInstance (e "a" "nixos"));
      instance-other = no (yen.allowed byInstance (e "b" "nixos"));
      narrow-instance = eq (yen.narrow all' byInstance).scopes [
        {
          all = [
            { path = [ T ]; }
            { instance = b.elemAt (hostAt "a") 1; }
          ];
        }
      ];
      narrow-path-instance = eq (yen.narrow g byInstance).scopes g.scopes;
      narrow-left = eq (yen.narrow all' g) g;
      narrow-right = eq (yen.narrow g all') g;
      narrow-disjoint = eq (yen.narrow g (yen.grant { scopes = [ (hostAt "b") ]; })).scopes [ ];
      # negative control: a scope id string is no ref, and covers nothing
      string = no (yen.allowed (yen.grant { scopes = [ "top:t/host:a" ]; }) (e "a" "fw"));
      refused = yes (
        (yen.stage {
          base = {
            imports = [ portsBase ];
          };
          change = {
            yen.aspects.firewall.at = [
              {
                kind = "host";
                name = "b";
              }
            ];
          };
          grant = g;
        }).refused != [ ]
      );
    };
  agent-json =
    let
      a =
        (ports {
          yen.host.c.port = 70000;
        }).agent;
    in
    {
      json = eq (b.fromJSON (b.toJSON a)) a;
      scopes = eq a.counts.scopes 4;
      errors = eq (b.length a.errors) 1;
      safe =
        eq
          (yen.jsonSafe {
            f = x: x;
            p = ./.;
          })
          {
            f = "<function>";
            p = toString ./.;
          };
    };
  agent-context =
    let
      r = ports (
        { yen, ... }:
        {
          yen.kinds.host.sinks.fw2 = { };
          yen.aspects.more = {
            at = yen.host.a;
            fw = "x";
            fw2 = "y";
          };
        }
      );
      c = r.context a { maxEdges = 1; };
      top = {
        kind = "top";
        name = "t";
      };
      a = {
        kind = "host";
        name = "a";
      };
    in
    {
      truncated = eq c.received.truncated {
        shown = 1;
        of = 3;
      };
      items = eq (b.length c.received.items) 1;
      aspects = eq c.aspects.items [
        { aspect = "firewall"; }
        { aspect = "more"; }
      ];
      parent = eq c.parent [ top ];
      scope = eq c.scope [
        top
        a
      ];
      edge-ends = eq (b.head c.received.items).to [
        top
        a
      ];
      unknown =
        eq
          (r.context [
            top
            (a // { name = "q"; })
          ] { }).code
          "unknown-scope";
      near = eq (b.length
        (r.context [
          top
          (a // { name = "q"; })
        ] { }).near
      ) 2;
      near-instance = eq (b.length (r.context (a // { name = "q"; }) { }).near) 2;
      scope-string = eq (r.context "top:t/host:a" { }).code "not-a-scope";
      json = eq (b.fromJSON (b.toJSON c)) c;
    };
  stored-queries =
    let
      # a parameter is typed; from JSON, a ref is its identity: { kind; name; }, { kind; } or { aspect; }
      r = ports (
        { yen, ... }:
        {
          yen.queries = {
            portOf = {
              params.host = yen.kinds.host;
              answer = { host, result }: host.port;
            };
            count = {
              params.kind = yen.lib.opt yen.lib.kind yen.kinds.host;
              answer = { kind, result }: b.length (b.filter (yen.lib.holds kind) result.scopes);
            };
            on = {
              params.aspect = yen.lib.aspect;
              answer =
                { aspect, result }: b.filter (id: result.active.${aspect.__aspect}.${id}) [ "top:t/host:a" ];
            };
            untyped = { result }: 1;
          };
        }
      );
      hostB = {
        kind = "host";
        name = "b";
      };
    in
    {
      catalog = eq (removeAttrs r.queries [ "untyped" ]) {
        count = {
          required = [ ];
          optional = [ "kind" ];
          types.kind = "a kind";
        };
        on = {
          required = [ "aspect" ];
          optional = [ ];
          types.aspect = "an aspect";
        };
        portOf = {
          required = [ "host" ];
          optional = [ ];
          types.host = "a host ref";
        };
      };
      port = eq (r.ask "portOf" { host = hostB; }) 80;
      # negative controls: a name string, an unknown instance and a ref of another kind are refused, never asked
      port-string = eq (r.ask "portOf" { host = "b"; }).code "ref";
      port-unknown =
        eq
          (r.ask "portOf" {
            host = hostB // {
              name = "c";
            };
          }).code
          "unknown-instance";
      port-other-kind =
        eq
          (r.ask "portOf" {
            host = hostB // {
              kind = "top";
              name = "t";
            };
          }).code
          "ref";
      count = eq (r.ask "count" { }) 2;
      count-kind = eq (r.ask "count" { kind.kind = "top"; }) 1;
      count-string = eq (r.ask "count" { kind = "top"; }).code "check";
      on = eq (r.ask "on" { aspect.aspect = "firewall"; }) [ "top:t/host:a" ];
      untyped = eq (r.ask "untyped" { }).code "query-untyped";
      untyped-error = eq (map (e: e.code) (b.filter (e: e.code == "query-untyped") r.errors)) [
        "query-untyped"
      ];
      missing = eq (r.ask "portOf" { }).code "missing-param";
      unknown-param =
        eq
          (r.ask "portOf" {
            host = hostB;
            hots = 1;
          }).code
          "unknown-param";
      near = eq (r.ask "portof" { }).near [ "portOf" ];
    };
  history =
    let
      h = yen.history {
        url = "https://github.com/vic/yen"; # the rev is on main; a flake eval has no .git to read
        revs = [
          "df8ee68d5244aeca4e4bf23f1e9ecc927226d620"
        ];
        module = "tests/fixtures/history.nix";
      };
    in
    {
      changes = eq (b.elemAt h 0).changes [ ];
      as-of =
        eq
          (yen.asOf {
            url = "https://github.com/vic/yen"; # the rev is on main; a flake eval has no .git to read
            rev = "df8ee68d5244aeca4e4bf23f1e9ecc927226d620";
            module = "tests/fixtures/history.nix";
          }).data.host.a.port
          22;
    };
  without =
    let
      w = yen.without {
        files = [
          ./fixtures/without/base.nix
          ./fixtures/without/db.nix
        ];
        path = [
          "host"
          "db"
        ];
      };
    in
    {
      dropped = eq w.dropped [ ./fixtures/without/db.nix ];
      no-db = yes (b.all (s: s.name != "db") w.result.scopes);
      web = yes (b.any (s: s.name == "web") w.result.scopes);
      nothing =
        eq
          (yen.without {
            files = [
              ./fixtures/without/base.nix
              ./fixtures/without/db.nix
            ];
            path = [
              "host"
              "nope"
            ];
          }).dropped
          [ ];
    };
  impact =
    let
      r = yen.eval {
        imports = [
          ./fixtures/without/base.nix
          ./fixtures/without/db.nix
        ];
      };
      db = {
        kind = "host";
        name = "db";
      };
      i = r.impact db { };
    in
    {
      reached = eq i.reached [
        {
          scope = [
            {
              kind = "top";
              name = "t";
            }
          ];
          depth = 1;
          via.sink = "peers";
        }
      ];
      truncated = eq i.truncated {
        shown = 1;
        of = 1;
      };
      sinks = eq (r.impact db { sinks = [ { sink = "nixos"; } ]; }).reached [ ];
      unknown-sink = eq (r.impact db { sinks = [ { sink = "peer"; } ]; }).code "unknown-sink";
      # negative controls: a sink or scope written as a string is no ref
      sink-string = eq (r.impact db { sinks = [ "peers" ]; }).code "unknown-sink";
      unknown-scope = eq (r.impact (db // { name = "dd"; }) { }).code "unknown-scope";
    };
  # .20: when a fleet has labels, an aspect from an unlabeled file has trust 0 (floor sees it); a prefix is literal,
  # never a regex ("agen./" does not label "agent/")
  labels-unlabeled =
    let
      r = yen.eval {
        imports = [
          ./fixtures/labels/modules/base.nix
          ./fixtures/labels/agent/web.nix
          { yen.aspects.extra.at = [ ]; }
        ];
      };
      lit = yen.eval {
        imports = [
          ./fixtures/labels/modules/base.nix
          ./fixtures/labels/agent/web.nix
          { yen.labels."agen./".trust = 0; } # as a regex it would match agent/ and win as the lowest
        ];
      };
    in
    {
      trust = eq r.labels.extra.trust 0;
      prefix = eq r.labels.extra.prefix null;
      literal = eq lit.labels.cache.trust 1;
    };
  # .20 .13: a staged change or a program carries its submitter's label; floor sees the agent, not a file
  labels-submitter =
    let
      base = {
        imports = [ ./fixtures/labels/modules/base.nix ];
      };
      s = yen.stage {
        inherit base;
        by = {
          name = "bot";
          trust = 1;
        };
        change = {
          yen.aspects.web.nixos.services.redis.enable = true;
        };
      };
      p = yen.program.dryRun {
        inherit base;
        by = {
          name = "bot";
          trust = 1;
        };
        prog = [
          {
            op = "place";
            aspect = "web";
            kind = "host";
            name = "h";
          }
        ];
      };
    in
    {
      by = eq s.labels.web.by "bot";
      trust = eq s.labels.web.trust 1;
      floor-web = yes (b.all (x: x.aspect == "web" && x.trust == 1) (s.floor 2));
      floor-some = yes (s.floor 2 != [ ]);
      program-by = eq p.labels.web.by "bot";
    };
  labels-floor =
    let
      r = yen.eval {
        imports = [
          ./fixtures/labels/modules/base.nix
          ./fixtures/labels/agent/web.nix
        ];
      };
    in
    {
      web = eq r.labels.web.trust 1;
      prefix = eq r.labels.web.prefix "agent/";
      cache = eq r.labels.cache.trust 1;
      floor-agent = yes (b.all (x: x.trust == 1 && b.match ".*agent/web.nix" x.file != null) (r.floor 3));
      floor-two = yes (b.length (r.floor 3) >= 2);
      floor-empty = eq (r.floor 1) [ ];
      base-only = eq (yen.eval { imports = [ ./fixtures/labels/modules/base.nix ]; }).labels.web.trust 3;
    };
  program-validate =
    let
      r = ports { };
      v = yen.program.validate r;
    in
    {
      valid = eq (v [
        {
          op = "set";
          path = [
            "host"
            "c"
            "port"
          ];
          value = 443;
        }
        {
          op = "place";
          aspect = "firewall";
          kind = "host";
          name = "c";
        }
      ]) [ ];
      near-kind = eq (map (e: e.near or null) (v [
        {
          op = "set";
          path = [
            "hots"
            "c"
            "port"
          ];
          value = 1;
        }
      ])) [ [ "host" ] ];
      near-field = eq (map (e: e.near or null) (v [
        {
          op = "set";
          path = [
            "host"
            "c"
            "prot"
          ];
          value = 1;
        }
      ])) [ [ "port" ] ];
      near-aspect = eq (map (e: e.near or null) (v [
        {
          op = "place";
          aspect = "firewal";
          kind = "host";
          name = "c";
        }
      ])) [ [ "firewall" ] ];
      near-op = eq (map (e: e.near or null) (v [ { op = "plac"; } ])) [ [ "place" ] ];
      empty-op = eq (b.length (v [ { } ])) 1;
    };
  program-dryrun =
    let
      base = {
        imports = [ portsBase ];
      };
      d =
        p:
        yen.program.dryRun {
          inherit base;
          prog = p;
        };
      ok = d [
        {
          op = "new";
          kind = "host";
          name = "c";
          fields.port = 443;
        }
        {
          op = "place";
          aspect = "firewall";
          kind = "host";
          name = "c";
        }
      ];
      bad = d [
        {
          op = "new";
          kind = "host";
          name = "c";
          fields.port = 443;
        }
      ];
    in
    {
      ok = yes ok.ok;
      valid = yes ok.valid;
      added = eq ok.diff.scopes.added [ "top:t/host:c" ];
      sha = yes (b.isString ok.sha);
      bad-not-ok = no bad.ok;
      bad-violations = eq bad.violations [ (nofw "top:t/host:c") ];
      invalid =
        no
          (d [
            {
              op = "set";
              path = [ "hots" ];
              value = 1;
            }
          ]).valid;
    };
  # D6: an undefined invariant is not ok
  r1-stage-incomplete =
    let
      s = r1stage {
        yen.aspects.cyc.at = [
          {
            kind = "top";
            name = "t";
          }
        ];
      } null;
    in
    {
      t1 = no (s.ok);
      t2 = eq (s.incomplete) ([
        [
          "bad"
          "cycle"
        ]
      ]);
    };
  # D7: the law cannot be switched off
  r1-no-invariants-arg = no ((b.functionArgs yen.stage) ? invariants);
  # D8: grants by path segment; added, removed and changed values all checked
  r1-grant-segment = {
    t1 = yes (
      yen.allowed r1grant {
        to = hostAt "web";
        sink.sink = "fw";
      }
    );
    t2 = no (
      yen.allowed r1grant {
        to = hostAt "webhook";
        sink.sink = "fw";
      }
    );
    t3 = yes (
      yen.allowed r1grant {
        to = hostAt "web" ++ [
          {
            kind = "user";
            name = "a";
          }
        ];
        sink.sink = "fw";
      }
    );
  };
  # D14 exact (R-yen): a change is refused only where its seeds reach through reads, once per scope (vic/r-yen.md)
  r1-grant-added = eq (r1outside (
    r1stage {
      yen.aspects.extra = {
        at = {
          kind = "host";
          name = "webhook";
        };
        fw = "x";
      };
    } r1grant
  )) ([ "top:t/host:webhook" ]);
  r1-grant-removed = eq (r1outside (r1stage { yen.host.db.bypass = true; } r1grant)) ([
    "top:t/host:db"
  ]);
  r1-grant-changed = eq (r1outside (r1stage { yen.host.db.port = 2222; } r1grant)) ([
    "top:t/host:db"
  ]);
  r1-grant-inside = eq (r1outside (r1stage { yen.host.web.port = 2222; } r1grant)) ([ ]);
  # the closure channel is closed: an element that reads another instance through `yen` is an eval error
  r1-grant-closure =
    no
      (b.tryEval (
        b.deepSeq
          (yen.eval (rung1 [
            (
              { yen, ... }:
              {
                yen.aspects.peer = {
                  at = yen.host.db;
                  fw = "${toString yen.host.web.port}";
                };
              }
            )
          ])).reduced.fw
          true
      )).success;
  # a read through a cycle request is an edge: a change at web reaches db, which asks for every host
  r1-grant-request = eq (r1outside (
    yen.stage {
      base = rung1 [
        (
          { yen, ... }:
          {
            yen.aspects.peer = {
              at = yen.host.db;
              cycle =
                { tree, ... }:
                let
                  hosts.instances = yen.kinds.host;
                in
                {
                  tree = [ hosts ];
                  fw = [ (toString (map (h: h.port) (b.head (tree.select hosts)))) ];
                };
            };
          }
        )
      ];
      change.yen.host.web.port = 2222;
      grant = r1grant;
    }
  )) ([ "top:t/host:db" ]);
  r1-grant-whole = eq ((r1stage { yen.host.db.port = 2222; } (yen.grant { scopes = [ [ T ] ]; }))
    .refused
  ) ([ ]);
  r1-grant-sinks = eq (r1outside (
    r1stage { yen.host.web.port = 2222; } (
      yen.grant {
        scopes = [ [ T ] ];
        sinks = [ { sink = "fw"; } ];
      }
    )
  )) ([ "top:t/host:web" ]); # the port reaches web's nixos, a sink the grant does not name
  r1-grant-noop = eq ((r1stage { } r1grant).refused) ([ ]);
  # one oracle per read channel, each with the read removed as its negative control (C1-C5, vic/quorum/r3-impact.md)
  r1-grant-channels =
    let
      reach =
        extra: change:
        r1outside (
          yen.stage {
            base = rung1 (
              [
                (
                  { yen, ... }:
                  {
                    yen.kinds.top.sinks.ports = { };
                  }
                )
              ]
              ++ extra
            );
            inherit change;
            grant = r1grant;
          }
        );
      # every host gives its port to top: a cycle reads every sink, so a C3 or C5 reader runs without it
      up = [
        (
          { yen, ... }:
          {
            yen.aspects.up = {
              at = yen.kinds.host;
              ports = { host, ... }: host.port;
            };
          }
        )
      ];
      port.yen.host.web.port = 2222;
      at-db = el: [
        (
          { yen, ... }:
          {
            yen.aspects.reader = {
              at = yen.host.db;
            }
            // el yen;
          }
        )
      ];
      asks =
        q:
        at-db (yen: {
          cycle =
            { tree, ... }:
            let
              r = q yen;
            in
            {
              tree = [ r ];
              fw = [ (b.length (tree.select r)) ];
            };
        });
    in
    {
      # C1: a sink arg reads the reduced value at its receiver
      c1 =
        eq
          (reach (
            up
            ++ at-db (_: {
              fw = { ports, ... }: b.length ports;
            })
          ) port)
          ([
            "top:t"
            "top:t/host:db"
          ]);
      # C2, and the control of C1: a kind arg reads the nearest instance of the kind: db's own host, never web
      c2 = eq (reach (
        up
        ++ at-db (_: {
          fw = { host, ... }: host.port;
        })
      ) port) ([ "top:t" ]);
      # C3: a tree request reads what it asks
      c3 = eq (reach (asks (yen: {
        scopesOf = yen.host.web;
      })) port) ([ "top:t/host:db" ]);
      c3-control = eq (reach (asks (yen: {
        scopesOf = yen.host.webhook;
      })) port) ([ ]);
      # C4: a spawned scope is new data; it reaches what reads it
      c4 =
        eq
          (reach up {
            yen.host.mail = { };
          })
          ([
            "top:t"
            "top:t/host:mail"
          ]);
      # C5: a whole-fleet reader is reached by every change, and a change that does nothing reaches nothing
      c5 = eq (reach (asks (_: {
        graph = true;
      })) port) ([ "top:t/host:db" ]);
      c5-control = eq (reach (asks (_: {
        graph = true;
      })) { }) ([ ]);
      # C6: a spawn reads instance data, so a scope's data can change with no declaration of its own
      c6 = eq (reach [
        (
          { yen, ... }:
          {
            yen.kinds.mirror = { };
            yen.kinds.host.spawns.mirror = s: if s.name == "db" then { m.port = yen.host.web.port; } else { };
          }
        )
      ] port) ([ "top:t/host:db/mirror:m" ]);
    };
  # D9: a change never declares the law
  r1-law-change =
    eq
      (map (e: e.code)
        (r1stage {
          yen.invariants.w = _: { bad = [ ]; };
        } null).refused
      )
      ([
        "law-change"
      ]);
  # D11: a program refused before is refused again
  r1-rejected-program =
    let
      prog = [
        {
          op = "set";
          path = [
            "host"
            "db"
            "port"
          ];
          value = 2222;
        }
      ];
    in
    eq (map (e: e.code)
      (yen.program.dryRun {
        base = rung1 [ ];
        inherit prog;
        rejected = [ (b.hashString "sha256" (b.toJSON prog)) ];
      }).refused
    ) ([ "rejected" ]);
}
