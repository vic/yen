# The query oracles of the engine: tests.query.<test> = { expr; expected; }. Run them: fastest --flake .#tests query
self:
let
  inherit (self.tests._shared)
    b
    codes
    eq
    fwRules
    good
    no
    nofw
    ports
    portsBase
    rung1
    yen
    yes
    ;

  # one error per code: a module, spawns, an element, a sink `of`, an order
  codesFix = yen.eval {
    imports = [
      (
        { yen, ... }:
        {
          yen.kinds.top = {
            spawns.host = _: {
              a = { };
              b = 3; # spawns: an instance that is no attrset
            };
            sinks.port.of = yen.lib.is builtins.isInt;
          };
          yen.kinds.host.spawns.svc = _: 1; # spawns: no attrset
          yen.kinds.svc = { };
          yen.top.t = { };
          yen.aspects.bare = {
            at = yen.kinds.top;
            port = x: x; # bare-function
          };
          yen.aspects.treeArg = {
            at = yen.kinds.top;
            port = { tree, ... }: 1; # arg: `tree` is a cycle source
          };
          yen.aspects.noArg = {
            at = yen.kinds.top;
            port = { host, ... }: 1; # arg: no host above top
          };
          yen.aspects.badOf = {
            at = yen.kinds.top;
            port = "x"; # of
          };
          yen.aspects.ord = {
            at = yen.kinds.top;
            order = "first"; # order
          };
        }
      )
      ({ nope }: { }) # module
    ];
  };
  hasFw = id: [
    "has"
    "firewall"
    id
  ];
  # a violation on one host: web runs sshd
  sshdWeb =
    { yen, ... }:
    {
      yen.invariants.no = _: {
        bad = [ ];
        pos = [ (yen.facts.has yen.aspects.sshd "top:t/host:web") ];
      };
    };
  # rung 2 fixture: hosts `a` (tag "b:1") and `a:b` (tag "2"); `ok` is a user relation of arity 1; `rules yen` names
  # the invariants
  tagsWith =
    rules: hosts:
    yen.eval (
      { yen, ... }:
      {
        yen.kinds.top.spawns.host = _: yen.host;
        yen.kinds.host.fields.tag = yen.lib.is (_: true);
        yen.top.t = { };
        yen.host = {
          a.tag = "b:1";
          "a:b".tag = "2";
        }
        // hosts;
        yen.relations.ok = {
          arity = 1;
          check = ts: b.match "[0-9]+" (b.head ts) != null; # digits only: tag "b:1" fails, "2" passes
        };
        yen.invariants = rules yen;
      }
    );
  tags = rules: tagsWith rules { };
  rule2 =
    r:
    tags (_: {
      inherit r;
    });
  rec1 = r: code: b.head (b.filter (e: e.code == code) r.errors);

in
{
  errors-v2-check =
    let
      e = rec1 (ports { yen.host.c.port = 70000; }) "check";
    in
    {
      want = eq e.want "Port";
      path = eq e.path [ "port" ];
      got = eq e.got 70000;
      class = eq e.class "fixable";
      from = eq e.from "host:c";
      error = eq e.error "port fails its check";
    };
  errors-v2-near = {
    close = eq (rec1 (ports { yen.host.b.prot = 1; }) "unknown-field").near [ "port" ];
    far = eq (rec1 (ports { yen.host.b.zzzzzz = 1; }) "unknown-field").near [ ];
  };
  errors-v2-two-answers =
    let
      e = rec1 (ports { yen.host.a.port = 23; }) "two-answers";
    in
    {
      path = eq e.path [
        "host"
        "a"
        "port"
      ];
      got = eq e.got 2;
    };
  declared-in =
    let
      r = ports { yen.aspects.firewall.nixos = { }; };
    in
    {
      two-files = eq (b.length (
        r.declaredIn [
          "aspects"
          "firewall"
        ]
      )) 2;
      none = eq (r.declaredIn [
        "aspects"
        "nope"
      ]) [ ];
    };
  invariants-check =
    let
      r = ports { };
    in
    {
      violations = eq r.check.violations [ (nofw "top:t/host:b") ];
      incomplete = eq r.check.incomplete [ ];
      not-ok = no r.check.ok;
      fixed-ok =
        yes
          (ports (
            { yen, ... }:
            {
              yen.aspects.fw-b = {
                at = yen.host.b;
                fw = "on";
              };
              yen.aspects.firewall.at = yen.host.b;
            }
          )).check.ok;
    };
  invariants-incomplete =
    let
      # ok "loop" holds when it does not: undefined, and so is the `bad` it proves
      r = ports (
        { yen, ... }:
        {
          yen.relations.ok.arity = 1;
          yen.invariants.loop = [
            (_: {
              head = yen.relations.ok "loop";
              neg = [ (yen.relations.ok "loop") ];
            })
            (_: {
              bad = [ ];
              pos = [ (yen.relations.ok "loop") ];
            })
          ];
        }
      );
      loop = [
        "bad"
        "loop"
      ];
    in
    {
      incomplete = eq r.check.incomplete [ loop ];
      not-violation = no (b.elem loop r.check.violations);
      not-ok = no r.check.ok;
    };
  schema-exact =
    let
      s =
        (ports (
          { yen, ... }:
          {
            yen.kinds.host.sinks.tags.reduce = yen.lib.reduce.set;
          }
        )).schema;
    in
    {
      host = eq s.kinds.host {
        fields.port.type = "Port";
        spawns = [ ];
        instances = 2;
        scopes = 2;
        sinks = {
          fw = {
            reduce = "list";
            of = null;
            feeds = [ ];
            conditional = false;
          };
          tags = {
            reduce = "set";
            of = null;
            feeds = [ ];
            conditional = false;
          };
        };
      };
      top-spawns = eq s.kinds.top.spawns [ "host" ];
      firewall = eq s.aspects.firewall {
        keys = [ "fw" ];
        cycle = false;
        files = [ "root" ];
        activeAt = 1;
      };
      invariants = eq s.invariants [ "fw" ];
      json = yes (b.isString (b.toJSON s));
    };
  explain =
    let
      r = ports (
        { yen, ... }:
        {
          yen.aspects.both.at = yen.lib.all [
            yen.kinds.host
            (yen.lib.not yen.aspects.firewall)
          ];
        }
      );
      e = r.explain both (host "b") 3;
      both.aspect = "both";
      host = name: {
        kind = "host";
        inherit name;
      };
      all' = b.head e.at.kids;
    in
    {
      active = yes e.active;
      op = eq all'.op "all";
      kids = eq (map (k: k.op) all'.kids) [
        "kind"
        "not"
      ];
      not-value = eq (b.head (b.elemAt all'.kids 1).kids).value false;
      cut = eq (b.head (r.explain both (host "a") 1).at.kids).kids "cut";
      near = eq (r.explain { aspect = "bth"; } (host "a") 1).near [ both ];
      # negative controls: names are no refs; an instance with no scope names none
      aspect-string = eq (r.explain "both" (host "a") 1).code "unknown-aspect";
      scope-string = eq (r.explain both "top:t/host:a" 1).code "not-a-scope";
      unknown-scope = eq (r.explain both (host "z") 1).code "unknown-scope";
      bad-path = eq (r.explain both [ (host "z") ] 1).code "unknown-scope";
      kind-node = eq (b.head all'.kids).kind { kind = "host"; };
      gives = eq (r.explain { aspect = "firewall"; } (host "a") 2).gives [
        {
          sink.sink = "fw";
          to = [
            {
              kind = "top";
              name = "t";
            }
            (host "a")
          ];
        }
      ];
      # the id is the path joined: what an answer prints is what a question takes
      round-trip = yes (b.all (s: (r.context (r.pathOf s) { }).scope == r.pathOf s) r.scopes);
    };
  field-facts =
    let
      r = ports (
        { yen, ... }:
        {
          yen.kinds.host.fields.peer = yen.lib.maybe yen.kinds.host;
          yen.host.b.peer = yen.host.a;
        }
      );
    in
    {
      val = yes (b.elem [ "val" "port" "top:t/host:a" 22 ] r.facts);
      ref = yes (b.elem [ "ref" "peer" "top:t/host:b" "host" "a" ] r.facts);
      no-reverse = no (b.elem [ "ref" "peer" "top:t/host:a" "host" "b" ] r.facts);
    };
  check-whynot =
    let
      r = ports (
        { yen, ... }:
        {
          yen.aspects.fw-b = {
            at = yen.host.b;
            fw = "on";
          };
          yen.aspects.firewall.at = yen.host.b;
          # a literal by reference, built where the refs are: the scope term is an instance
          yen.flake =
            { ... }:
            {
              kindA = yen.facts.kind yen.kinds.host yen.host.a;
            };
        }
      );
      # an instance as a caller outside the fleet writes it: its identity
      host = name: {
        kind = "host";
        inherit name;
      };
      bad = r.check.bad.fw (host "b");
      twice = ports (
        { yen, ... }:
        {
          yen.kinds.top.spawns.host = _: yen.host;
          yen.kinds.second.spawns.host = _: yen.host;
          yen.second.s = { };
        }
      );
    in
    {
      ok = yes r.check.ok;
      blocking = yes (b.any (x: x.blocking == [ (hasFw "top:t/host:b") ]) (r.check.whyNot bad));
      proof = eq (r.check.proof r.flake.kindA).atom [
        "kind"
        "host"
        "top:t/host:a"
      ];
      holds = eq ((ports { }).check.whyNot ((ports { }).check.bad.fw (host "b"))) [ ];
      # a scope record is its own scope
      scope-record = eq (r.check.whyNot (
        r.check.bad.fw (b.head (b.filter (s: s.id == "top:t/host:b") r.scopes))
      )) (r.check.whyNot bad);
      # negative controls: a hand-written list is no literal; an instance with two scopes names no one scope
      list = eq (r.check.whyNot (nofw "top:t/host:b")).code "not-a-literal";
      ambiguous = eq (twice.check.why (twice.check.bad.fw (host "b"))).code "scope-ambiguous";
      unknown-instance = eq (r.check.why (r.check.bad.fw (host "z"))).code "unknown-scope";
    };
  # D10: explanations and the verdict read one model; a fact no rule mentions is still true
  explain-same-model =
    let
      c = (ports { }).check;
      a = c.facts.scope {
        kind = "host";
        name = "a";
      };
    in
    {
      proof = eq (c.proof a).atom [
        "scope"
        "top:t/host:a"
      ];
      why-not = eq (c.whyNot a) [ ];
    };
  invariants-why =
    eq
      (b.head (
        (ports { }).check.why (
          (ports { }).check.bad.fw {
            kind = "host";
            name = "b";
          }
        )
      )).neg
      [
        (hasFw "top:t/host:b")
      ];
  # rung 1: outputs only from a clean fleet (D0)
  r1-clean-flake = eq (yen.eval (rung1 [ ])).flake { ok = true; };
  r1-violation-no-flake =
    let
      f = (yen.eval (rung1 [ sshdWeb ])).flake;
    in
    {
      t1 = eq (builtins.attrNames f) ([ "invalid-flake-errors" ]);
      t2 = eq (f.invalid-flake-errors) ({
        errors = [ ];
        violations = [
          [
            "bad"
            "no"
          ]
        ];
        incomplete = [ ];
      });
    };
  r1-error-no-flake =
    let
      f =
        (yen.eval (rung1 [
          { yen.host.web.port = 1; }
          { yen.host.web.port = 2; }
        ])).flake.invalid-flake-errors;
    in
    {
      t1 = eq (map (e: e.code) f.errors) ([ "two-answers" ]);
      t2 = eq (f.violations) ([ ]);
    };
  # D13: a fleet that is not clean gives no reduced values to build outputs from by hand
  r1-violation-no-reduced = {
    t1 = eq ((yen.eval (rung1 [ sshdWeb ])).reduced) (null);
    t2 = yes ((yen.eval (rung1 [ ])).reduced.nixos ? "top:t/host:web");
  };
  # a flake that cannot be filled is an error record, never a silent null
  flake-fill-error =
    let
      r = yen.eval {
        yen.kinds.top.spawns = { };
        yen.kinds.host = { };
        yen.top.t = { };
        yen.flake = { host, ... }: host; # no host under top: the arg has no answer
      };
    in
    {
      t1 = eq (builtins.attrNames r.flake) ([ "invalid-flake-errors" ]);
      t2 = yes (b.any (e: e.code == "arg" && e.want == "host") r.errors);
    };
  # D9: a rule never derives a fact yen extracts; it is an error, and the fleet gives no outputs
  r1-edb-head =
    let
      r = yen.eval (rung1 [
        (
          { yen, ... }:
          {
            yen.invariants.f = _: { head = yen.facts.has yen.aspects.fw "top:t/host:web"; };
          }
        )
      ]);
    in
    {
      t1 = eq (codes r) ([ "edb-head" ]);
      t2 = eq (builtins.attrNames r.flake) ([ "invalid-flake-errors" ]);
    };
  # rung 2 (vic/formally-verified.md section 3): typed facts, relations, rules as data
  # two hosts whose colon strings collide (D1): two facts, and a rule on one never fires on the other
  r2-no-collision =
    let
      r = tags (yen: {
        collide = _: {
          bad = [ ];
          pos = [ (yen.facts.host.tag "top:t/host:a:b" "1") ];
        };
      });
    in
    {
      t1 = yes (r.check.ok);
      t2 = yes (b.elem [ "val" "tag" "top:t/host:a" "b:1" ] r.facts);
      t3 = yes (b.elem [ "val" "tag" "top:t/host:a:b" "2" ] r.facts);
    };
  # the same rule with a variable binds over both hosts, and lt keeps one pair
  r2-vars =
    eq
      ((tags (yen: {
        pair =
          {
            A,
            B,
            X,
            Y,
          }:
          {
            bad = [
              A
              B
            ];
            pos = [
              (yen.facts.host.tag A X)
              (yen.facts.host.tag B Y)
              (yen.facts.lt A B)
            ];
          };
      })).check.violations
      )
      ([
        [
          "bad"
          "pair"
          "top:t/host:a"
          "top:t/host:a:b"
        ]
      ]);
  # D3: a rule is a function of its variables; an invariant written as data is an error and gives no rules
  r2-invariant-data =
    let
      r = yen.eval (rung1 [ { yen.invariants.f = [ { head = [ "bad" ]; } ]; } ]);
    in
    {
      t1 = eq (codes r) ([ "invariant-data" ]);
      t2 = eq (builtins.attrNames r.flake) ([ "invalid-flake-errors" ]);
    };
  r2-parent-fact = yes (b.elem [ "parent" "top:t/host:a" "top:t" ] (tags (_: { })).facts);
  # .41 (E1): a field a rule reads through an even number of `not` from `bad` gives a fact for every value, or the
  # verdict is not ok. Host a.tag is an attrset: no fact, so `bad` could be missed. Read under `not`, a missing fact
  # can only add a violation, so it is safe.
  r3-opaque =
    let
      meta =
        tagsWith
          (yen: {
            x =
              { H }:
              {
                bad = H;
                pos = [ (yen.facts.host.tag H "x") ];
              };
          })
          {
            a.tag = {
              x = 1;
            };
          };
      safe =
        tagsWith
          (yen: {
            x =
              { H }:
              {
                bad = H;
                pos = [ (yen.facts.kind yen.kinds.host H) ];
                neg = [ (yen.facts.host.tag H "x") ];
              };
          })
          {
            a.tag = {
              x = 1;
            };
          };
    in
    {
      t1 = no (meta.check.ok);
      t2 = eq (meta.check.opaque) ([
        {
          field = "tag";
          scopes = [ "top:t/host:a" ];
        }
      ]);
      t3 = eq (safe.check.opaque) ([ ]);
    };
  # .43: where a fact comes from is its own answer, never part of the fact: one fact, two files
  r3-provenance =
    let
      r = yen.eval {
        imports = [
          portsBase
          { yen.host.a.port = 22; }
        ];
      };
      a = [
        "instance"
        "top:t/host:a"
        "host"
        "a"
      ];
      F = r.check.facts;
      hostA = {
        kind = "host";
        name = "a";
      };
    in
    {
      t1 = eq (b.length (b.filter (x: x == a) r.facts)) (1);
      # the question is a literal, by reference: identities from outside the fleet, no scope id written
      t2 = eq (b.length (r.check.from (F.instance hostA hostA))) (2);
      t3 = eq (b.length (r.check.from (F.has { aspect = "firewall"; } hostA))) (1);
      t4 = eq (r.check.from (F.edge { sink = "fw"; } hostA hostA)) ([ "aspect firewall" ]);
      list = eq (r.check.from a).code "not-a-literal";
    };
  # .42: a seal binds the verdict to its rules, facts and engine; checking it means evaluating again
  r3-seal =
    let
      p = ports { };
      seal = p.check.seal;
      tamper = seal // {
        certificate = seal.certificate // {
          false = seal.certificate.false ++ [
            {
              atom = nofw "top:t/host:b";
              stage = 0;
            }
          ];
        };
      };
    in
    {
      t1 = eq (p.check.verify seal) ({
        ok = true;
      });
      t2 = eq ((ports { yen.host.c.port = 1; }).check.verify seal) ({
        ok = false;
        why = "facts";
      });
      t3 = eq ((p.check.verify tamper).why) ("certificate");
      t4 =
        eq
          (
            (ports (
              { yen, ... }:
              {
                yen.invariants.more = fwRules yen;
              }
            )).check.verify
            seal
          )
          ({
            ok = false;
            why = "rules";
          });
    };
  # rung 3: each verdict ships a staged certificate that the plain checker accepts, and it states the same verdict
  r3-certified =
    let
      p = (ports { }).check;
      c =
        (yen.eval (rung1 [
          {
            yen.aspects.cyc.at = [
              {
                kind = "top";
                name = "t";
              }
            ];
          }
        ])).check;
    in
    {
      t1 = yes (p.certified);
      t2 = yes (b.elem (nofw "top:t/host:b") (map (e: e.atom) p.certificate.true));
      t3 = yes (c.certified);
      t4 = yes (c.incomplete != [ ]);
      t5 = no ((b.elem [ "bad" "cycle" ] (map (e: e.atom) (c.certificate.true ++ c.certificate.false))));
    };
  # the verdict as the Lean checker reads it (lean/Main.lean): JSON, every atom its key, one entry per certificate entry
  lean-export =
    let
      p = (ports { }).check;
    in
    {
      json = yes (b.isString (b.toJSON p.lean));
      proved = eq (map (e: e.atom) p.lean.certificate.proved) (
        map (e: map b.toJSON e.atom) p.certificate.true
      );
      refuted = eq (b.length p.lean.certificate.refuted) (b.length p.certificate.false);
      # the rules as written: a variable stays { var; }, a constant is its key
      rules = yes (
        b.all (
          r: b.all (a: b.all (t: b.isString t || t ? var) a) ([ r.head ] ++ r.pos ++ r.neg)
        ) p.lean.rules
      );
      vars = yes (b.any (r: b.any (t: !(b.isString t)) r.head) p.lean.rules);
      facts = eq (b.length p.lean.facts) (b.length (ports { }).facts);
    };
  # a derived tuple that fails its relation's check is an error (ok takes one string term here)
  relation-check =
    let
      r = tagsWith (yen: {
        r =
          { H, X }:
          {
            head = yen.relations.ok X;
            pos = [ (yen.facts.host.tag H X) ];
          };
      }) { };
    in
    eq (codes r) ([ "relation-check" ]);
  # a literal is a reference: a string, or a hand-written list of strings, is a bad atom
  r2-string-atom = {
    t1 = eq (codes (
      rule2 (_: {
        head = "bad:x";
      })
    )) ([ "bad-atom" ]);
    t2 = eq (codes (
      rule2 (_: {
        bad = [ ];
        pos = [
          [
            "kind"
            "host"
            "top:t/host:a"
          ]
        ];
      })
    )) ([ "bad-atom" ]);
  };
  # the guards below hold for a literal built by hand, outside yen.facts and yen.relations
  r2-unknown-relation =
    let
      e =
        b.head
          (rule2 (_: {
            head = {
              atom = [
                "okk"
                "x"
              ];
              join = [ ];
            };
          })).errors;
    in
    {
      t1 = eq (e.code) ("unknown-relation");
      t2 = eq (e.near) ([ "ok" ]);
    };
  r2-arity = eq (codes (
    rule2 (_: {
      head = {
        atom = [ "ok" ];
        join = [ ];
      };
    })
  )) ([ "arity" ]);
  r2-unsafe = eq (codes (
    rule2 (
      { X }:
      {
        bad = X;
      }
    )
  )) ([ "unsafe-rule" ]);
  # refs in rules: a ref field joins its target's scope; negated, the join goes to pos (one instance per scope)
  refs-db-same-env =
    let
      fleet =
        extra:
        yen.eval (
          { yen, ... }:
          {
            imports = [ extra ];
            yen.kinds.top.spawns.env = _: yen.env;
            yen.kinds.env.spawns.host =
              s:
              b.removeAttrs yen.host (
                if s.name == "lab" then
                  [
                    "db"
                    "web"
                  ]
                else
                  [ "api" ]
              );
            yen.kinds.host.fields = {
              env = yen.kinds.env;
              db = yen.lib.maybe yen.kinds.host;
            };
            yen.top.t = { };
            yen.env.prod = { };
            yen.env.lab = { };
            yen.host.db.env = yen.env.prod;
            yen.host.web = {
              env = yen.env.prod;
              db = yen.host.db;
            };
            yen.invariants = {
              same-env =
                {
                  H,
                  D,
                  E,
                }:
                {
                  bad = H;
                  pos = [
                    (yen.facts.host.db H D)
                    (yen.facts.host.env H E)
                  ];
                  neg = [ (yen.facts.host.env D E) ];
                };
              db-set =
                { H }:
                {
                  bad = H;
                  pos = [ (yen.facts.host.db.set H) ];
                };
            };
          }
        );
      lab = fleet (
        { yen, ... }:
        {
          yen.host.api = {
            env = yen.env.lab;
            db = yen.host.db;
          };
        }
      );
    in
    {
      t1 = eq (b.filter (a: b.elemAt a 1 == "same-env") (fleet { }).check.violations) ([ ]);
      t2 = eq (b.filter (a: b.elemAt a 1 == "same-env") lab.check.violations) ([
        [
          "bad"
          "same-env"
          "top:t/env:lab/host:api"
        ]
      ]);
      t3 = eq (b.filter (a: b.elemAt a 1 == "db-set") lab.check.violations) ([
        [
          "bad"
          "db-set"
          "top:t/env:lab/host:api"
        ]
        [
          "bad"
          "db-set"
          "top:t/env:prod/host:web"
        ]
      ]);
      t4 = eq (lab.errors) ([ ]);
    };
  r2-unencodable =
    let
      r = tagsWith (_: { }) { "a:b".tag = 1.5; };
    in
    {
      t1 = eq (codes r) ([ "unencodable" ]);
      t2 = eq ((b.head r.errors).path) ([ "tag" ]);
    };
  error-codes = {
    t1 = eq (map (e: e.code) codesFix.errors) ([
      "module"
      "spawns"
      "spawns"
      "order"
      "of"
      "bare-function"
      "arg"
      "arg"
    ]);
    t2 = eq ((b.elemAt codesFix.errors 6).want) ("host");
    t3 = eq ((b.elemAt codesFix.errors 7).error) ("aspect treeArg: arg `tree` is a cycle source");
    t4 = eq ((b.elemAt codesFix.errors 5).error) ("aspect bare: bare function: wrap it as `{ ... }:`");
  };
  graph-edges = yes (
    b.elem {
      sink = "persist";
      from = "fleet:main/host:lb";
      to = "fleet:main/host:lb";
      origin = "aspect motd";
    } good.graph.edges
  );
}
