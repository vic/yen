# The model oracles of the engine: tests.model.<test> = { expr; expected; }. Run them: fastest --flake .#tests model
self:
let
  inherit (self.tests._shared)
    b
    codes
    eq
    feat
    featLazy
    fleet
    gaps
    has
    hostOf
    ids
    msgs
    no
    noAddr
    presence
    yen
    yes
    ;
in
{
  # enum and attrsOf are types: a check, and a description for the error record
  # enum and attrsOf are types: a check, and a description for the error record
  type-enum =
    eq
      [
        (
          (yen.enum [
            "a"
            "b"
          ]).check
          "a"
        )
        (
          (yen.enum [
            "a"
            "b"
          ]).check
          "c"
        )
        (yen.enum [
          "a"
          "b"
        ]).description
      ]
      [
        true
        false
        "one of \"a\", \"b\""
      ];
  type-attrsOf =
    eq
      [
        ((yen.attrsOf (yen.is b.isInt)).check { x = 1; })
        ((yen.attrsOf (yen.is b.isInt)).check { x = "1"; })
        ((yen.attrsOf (yen.is b.isInt)).check { })
        ((yen.attrsOf (yen.is b.isInt)).check [ 1 ])
      ]
      [
        true
        false
        true
        false
      ];
  # a declared bound that is null is open
  valid-at-null = {
    open = yes (
      yen.validAt "2026-11-15" {
        validFrom = null;
        validTo = null;
      }
    );
    from = yes (
      yen.validAt "2026-11-15" {
        validFrom = "2026-01-01";
        validTo = null;
      }
    );
    to = no (
      yen.validAt "2026-11-15" {
        validFrom = null;
        validTo = "2026-10-31";
      }
    );
  };
  valid-at =
    let
      r = yen.eval (
        { yen, ... }:
        {
          imports = [ ./fixtures/history.nix ];
          yen.aspects.backup.at = yen.lib.all [
            yen.kinds.host
            (yen.lib.validAt "2026-11-15")
          ];
          yen.aspects.late.at = yen.lib.all [
            yen.kinds.host
            (yen.lib.validAt "2027-01-01")
          ];
        }
      );
    in
    {
      backup-a = yes r.active.backup."top:t/host:a";
      backup-b = yes r.active.backup."top:t/host:b";
      late-a = no r.active.late."top:t/host:a";
      late-b = yes r.active.late."top:t/host:b";
    };
  neg-missing-addr = yes (has noAddr "missing addr");
  # D13: an error withholds the outputs and the reduced values (good-persist reads them on the clean fleet)
  neg-missing-addr-withholds = {
    reduced = eq noAddr.reduced null;
    flake = eq (builtins.attrNames noAddr.flake) [ "invalid-flake-errors" ];
  };
  neg-unknown-field = yes (
    has (yen.eval (fleet {
      addr = "a";
      adr = "b";
    })) "unknown field adr"
  );
  neg-bad-check = yes (
    has (yen.eval (fleet {
      addr = 1;
    })) "addr fails its check"
  );
  bad-check-reads-null = eq ((hostOf (
    yen.eval (fleet {
      addr = 1;
    })
  )).addr
  ) (null);
  two-answers = yes (
    has (yen.eval {
      imports = [
        (fleet { addr = "a"; })
        { yen.host.lb.addr = "b"; }
      ];
    }) "two answers for host.lb.addr"
  );
  same-answer-twice-ok = eq (msgs (
    yen.eval {
      imports = [
        (fleet { addr = "a"; })
        { yen.host.lb.addr = "a"; }
      ];
    }
  )) ([ ]);
  settings-value = eq ((hostOf (feat {
    settings.zfs.arcMax = 8;
  })).settings.zfs.arcMax
  ) (8);
  settings-default = eq ((hostOf (feat { })).settings.k3s.role) ("agent");
  settings-maybe-null = eq ((hostOf (feat { })).settings.zfs.arcMax) (null);
  settings-lazy = eq ((hostOf featLazy).settings.k3s.role) ("agent"); # reading zfs never forces settings.lazy's default
  settings-unknown = yes (has (feat { settings.zfz = 1; }) "unknown field settings.zfz");
  # c47 rung 1: a kind declares kinds inside it; a nested kind is reached only through its parent
  nested-kinds-r1 =
    let
      r = yen.eval (
        { yen, ... }:
        {
          yen.kinds.x = {
            spawns = { }; # a root: the flake needs one scope
            kinds.y = { };
          };
          yen.x.a = { };
          yen.flake =
            { ... }:
            {
              id = yen.kinds.x.kinds.y.__kind;
              flat = yen.kinds ? y;
            };
        }
      );
      typo = yen.eval { yen.kinds.x.kinds.y.feilds = { }; };
    in
    {
      clean = eq r.errors [ ];
      id = eq r.flake.id [
        "x"
        "y"
      ];
      not-flat = no r.flake.flat;
      typo = eq (map (e: e.path) typo.errors) [
        [
          "yen"
          "kinds"
          "x"
          "kinds"
          "y"
          "feilds"
        ]
      ];
    };
  # c47 rung 2: a nested kind is spawned from its parent's data by default; an explicit spawns replaces it
  nested-kinds-r2 =
    let
      ids = r: map (s: s.id) r.scopes;
      nested =
        spawns:
        yen.eval (
          { yen, ... }:
          {
            yen.kinds.x = {
              inherit spawns;
              kinds.y = { };
            };
            yen.x.a.y = {
              b = { };
              c = { };
            };
            yen.aspects.p.at = yen.kinds.x.kinds.y;
          }
        );
      flat = yen.eval (
        { yen, ... }:
        {
          yen.kinds.x = {
            fields.y = yen.lib.is b.isAttrs; # flat: the child data is a field of x
            spawns.y = s: s.y;
          };
          yen.kinds.y = { };
          yen.x.a.y = {
            b = { };
            c = { };
          };
        }
      );
      dflt = nested { };
      only-b = nested { y = s: { inherit (s.y) b; }; };
    in
    {
      clean = eq dflt.errors [ ];
      same-as-flat = eq (ids dflt) (ids flat);
      kind = eq (map (s: s.kind) dflt.scopes) [
        "x"
        [
          "x"
          "y"
        ]
        [
          "x"
          "y"
        ]
      ];
      at-nested = eq dflt.active.p {
        "x:a" = false;
        "x:a/y:b" = true;
        "x:a/y:c" = true;
      };
      explicit = eq (ids only-b) [
        "x:a"
        "x:a/y:b"
      ];
      spawn-none = eq (ids (nested {
        y = _: { };
      })) [ "x:a" ];
    };
  # c47 rung 3a: a spawn from a nested kind counts; a nested scope reads by path; nested names cannot shadow
  nested-kinds-r3a =
    let
      ids = r: map (s: s.id) r.scopes;
      spawnsTop = yen.eval (
        { yen, ... }:
        {
          yen.kinds.x.kinds.y = {
            fields.d = yen.lib.is b.isAttrs;
            spawns.d = s: s.d;
          };
          yen.kinds.d.spawns = { };
          yen.x.a.y.b.d.e = { };
          yen.d.e = { };
        }
      );
      nested = yen.eval (
        { yen, ... }:
        {
          yen.kinds.x.kinds.y = { };
          yen.x.a.y.b = { };
          yen.x.a2.y.b = { };
          yen.aspects.p.at = yen.kinds.x.kinds.y;
        }
      );
      p.aspect = "p";
      y = name: {
        kind = [
          "x"
          "y"
        ];
        inherit name;
      };
      # the whole record, message included, is JSON: a list kind never reaches a string as is
      code = t: (b.fromJSON (b.toJSON (nested.explain p t 1))).code;
      errs = m: map (e: { inherit (e) code path; }) (yen.eval m).errors;
      reserved = path: [
        {
          code = "reserved";
          path = [ "yen" ] ++ path;
        }
      ];
      notKind = path: [
        {
          code = "not-a-kind";
          path = [ "yen" ] ++ path;
        }
      ];
    in
    {
      scope-key = eq (errs { yen.kinds.x.kinds.y.kinds.__here = { }; }) (reserved [
        "kinds"
        "x"
        "kinds"
        "y"
        "kinds"
        "__here"
      ]);
      field-name =
        eq
          (errs (
            { yen, ... }:
            {
              yen.kinds.x = {
                fields.y = yen.lib.is b.isAttrs;
                kinds.y = { };
              };
            }
          ))
          (reserved [
            "kinds"
            "x"
            "kinds"
            "y"
          ]);
      kinds-not-attrs = eq (errs { yen.kinds.x.kinds = 5; }) (notKind [
        "kinds"
        "x"
        "kinds"
      ]);
      kind-not-attrs = eq (errs { yen.kinds.x.kinds.y = 5; }) (notKind [
        "kinds"
        "x"
        "kinds"
        "y"
      ]);
      top-not-attrs = eq (errs { yen.kinds.x = 5; }) (notKind [
        "kinds"
        "x"
      ]);
      # PROPOSED, not ruled by vic: a nested kind named like a top kind
      top-name =
        eq
          (errs {
            yen.kinds.d = { };
            yen.kinds.x.kinds.d = { };
          })
          (reserved [
            "kinds"
            "x"
            "kinds"
            "d"
          ]);
      round-trip = yes (
        b.all (s: (nested.context (nested.pathOf s) { }).scope == nested.pathOf s) nested.scopes
      );
      unknown-nested = eq (code (y "z")) "unknown-scope";
      unknown-nested-path = eq (code [ (y "z") ]) "unknown-scope";
      ambiguous = eq (code (y "b")) "scope-ambiguous";
      # two parents each hold a y.b: the parent keeps their scopes apart
      distinct-parents = eq (ids nested) [
        "x:a"
        "x:a/y:b"
        "x:a2"
        "x:a2/y:b"
      ];
      # the refusal names a nested scope by its kind path; JSON forces the message
      grant-nested =
        eq
          (b.fromJSON (
            b.toJSON
              (yen.stage {
                base =
                  { yen, ... }:
                  {
                    yen.kinds.x.kinds.y.sinks.fw = { };
                    yen.x.a.y.b = { };
                    yen.aspects.p.at = yen.kinds.x.kinds.y;
                  };
                change.yen.aspects.p.fw = "on";
                grant = yen.grant {
                  scopes = [
                    [
                      {
                        kind = "x";
                        name = "a";
                      }
                      (y "c")
                    ]
                  ];
                };
              }).refused
          ))
          [
            {
              class = "authority";
              code = "outside-grant";
              error = "the change can reach x a/x.kinds.y b, outside the grant";
              from = "stage";
              got = [
                {
                  kind = "x";
                  name = "a";
                }
                (y "b")
              ];
              path = [ ];
            }
          ];
      spawns-top-once = eq (ids spawnsTop) [
        "x:a"
        "x:a/y:b"
        "x:a/y:b/d:e"
      ];
    };
  # c47 rung 3c: the data of a nested instance is typed by its own kind
  nested-kinds-r3c =
    let
      typed = data: group { b = data; };
      group =
        y:
        yen.eval (
          { yen, ... }:
          {
            yen.kinds.x = {
              fields.foo = yen.lib.is b.isInt;
              kinds.y.fields = {
                bar = yen.lib.is b.isInt;
                n = yen.lib.opt (yen.lib.is b.isInt) 7;
                # a derived default reads its own nested instance
                n2 = yen.lib.derive (yen.lib.is b.isString) (i: "${i.name}:${toString i.bar}");
              };
            };
            yen.x.a = {
              foo = 1;
              inherit y;
            };
          }
        );
      three =
        q:
        yen.eval (
          { yen, ... }:
          {
            yen.kinds.x.kinds.y.kinds.z.fields.q = yen.lib.is b.isInt;
            yen.x.a.y.b.z.c = { inherit q; };
          }
        );
      errs = r: map (e: { inherit (e) code from path; }) r.errors;
      # a nested instance error has the full data path (design-c47-nesting.md rung 3)
      err = code: field: [
        {
          inherit code;
          from = "x:a/y:b";
          path = [
            "x"
            "a"
            "y"
            "b"
            field
          ];
        }
      ];
    in
    {
      clean = eq (typed { bar = 2; }).errors [ ];
      default = eq (map (s: s.n or null) (typed { bar = 2; }).scopes) [
        null
        7
      ];
      derive = eq (map (s: s.n2 or null) (typed { bar = 2; }).scopes) [
        null
        "b:2"
      ];
      check = eq (errs (typed {
        bar = "2";
      })) (err "check" "bar");
      unknown = eq (errs (typed {
        bar = 2;
        baz = 3;
      })) (err "unknown-field" "baz");
      # the fix names the nested kind by its path
      unknown-fix =
        eq
          (b.head
            (typed {
              bar = 2;
              baz = 3;
            }).errors
          ).fix
          "declare yen.kinds.x.kinds.y.fields.baz, or use a declared field";
      three-clean = eq (three 1).errors [ ];
      three-check = eq (errs (three "1")) [
        {
          code = "check";
          from = "x:a/y:b/z:c";
          path = [
            "x"
            "a"
            "y"
            "b"
            "z"
            "c"
            "q"
          ];
        }
      ];
      # only the bad member reports
      one-bad-member =
        eq
          (errs (group {
            b.bar = 2;
            c.bar = "2";
          }))
          [
            {
              code = "check";
              from = "x:a/y:c";
              path = [
                "x"
                "a"
                "y"
                "c"
                "bar"
              ];
            }
          ];
      # a nested group or member that is not an attrset is an error, never a lost value
      group-not-set = eq (errs (group 5)) [
        {
          code = "check";
          from = "x:a";
          path = [
            "x"
            "a"
            "y"
          ];
        }
      ];
      # the error names the kind of the bad value, never the value: a mis-keyed secret does not leak
      not-set-got-string = eq (b.map (e: e.got) (group "hunter2").errors) [ "string" ];
      not-set-no-leak = no (b.match ".*hunter2.*" (b.toJSON (group "hunter2").errors) != null);
      not-set-got-lambda = eq (b.map (e: e.got) (group (_: 1)).errors) [ "lambda" ];
      not-set-json = yes (b.isString (b.toJSON (group (_: 1)).errors));
      not-set-got-types =
        eq
          (b.map (v: (b.head (group v).errors).got) [
            5
            "s"
            [ ]
            null
          ])
          [
            "int"
            "string"
            "list"
            "null"
          ];
      # a leaf is an attrset to `isAttrs`, but not a group
      leaf-not-set = eq (b.map (e: { inherit (e) code got path; }) (group (yen.is b.isInt)).errors) [
        {
          code = "check";
          got = "set";
          path = [
            "x"
            "a"
            "y"
          ];
        }
      ];
      member-not-set = eq (errs (typed 5)) [
        {
          code = "check";
          from = "x:a/y:b";
          path = [
            "x"
            "a"
            "y"
            "b"
          ];
        }
      ];
    };
  # c47: a ref to a nested kind is not supported yet; each use is a yen error, never a Nix throw (GH #61)
  nested-kinds-refs =
    let
      fleet =
        extra:
        yen.eval (
          { yen, ... }:
          {
            imports = [ (extra yen) ];
            yen.kinds.x = {
              sinks.seen = { };
              kinds.y.fields.bar = yen.lib.is b.isInt;
            };
            yen.x.a.y.b.bar = 1;
          }
        );
      # JSON forces every message
      errs = r: map (e: { inherit (e) code error fix; }) (b.fromJSON (b.toJSON r.errors));
      err = code: [
        {
          inherit code;
          error = "`yen.kinds.x.kinds.y` is a nested kind: refs to nested kinds are not supported here yet";
          fix = "use a top kind here: a nested kind is reached only through its parent";
        }
      ];
      field = fleet (yen: {
        yen.kinds.t.fields.target = yen.kinds.x.kinds.y;
        yen.t.u.target = yen.x.a.y.b;
      });
      request = fleet (yen: {
        yen.aspects.see = {
          at = yen.kinds.x;
          cycle =
            { tree, ... }:
            let
              all.instances = yen.kinds.x.kinds.y;
            in
            {
              tree = [ all ];
              seen = tree.select all;
            };
        };
      });
      of = fleet (yen: {
        yen.kinds.x.sinks.ys.of = yen.kinds.x.kinds.y;
        yen.aspects.put = {
          at = yen.kinds.x.kinds.y;
          ys = { scope, ... }: scope;
        };
      });
      # a ref from JSON names a nested instance by its kind path
      ask =
        q: f:
        (fleet (yen: {
          yen.queries.one = {
            params.it = yen.kinds.x;
            answer = { it, result }: it.name;
          };
          yen.queries.many = {
            params.it = yen.lib.listOf yen.kinds.x;
            answer = { it, result }: b.length it;
          };
          yen.queries.typed = {
            params.it = yen.kinds.x.kinds.y;
            answer = { it, result }: it.name;
          };
        })).ask
          q
          {
            it = f {
              kind = [
                "x"
                "y"
              ];
              name = "b";
            };
          };
    in
    {
      field = eq (errs field) (err "ref");
      request = eq (errs request) (err "tree-request");
      of = eq (errs of) (err "of");
      of-agent = yes (b.isString (b.toJSON of.agent));
      of-reads = yes (b.isString (b.toJSON of.reads));
      ask = eq (errs { errors = [ (ask "one" (r: r)) ]; }) (err "ref");
      ask-list = eq (errs { errors = [ (ask "many" (r: [ r ])) ]; }) (err "ref");
      ask-type = eq (errs { errors = [ (ask "typed" (r: r // { kind = "x"; })) ]; }) (err "ref");
    };
  # #83: an aspect at a nested kind asks for a kind arg by the leaf name; it reads the nearest ancestor scope of that kind
  nested-kind-args =
    let
      fns = {
        hu =
          { host, user, ... }:
          {
            "${host.name}/${user.name}" = "x";
          };
        u =
          { user, ... }:
          {
            "${user.name}" = "x";
          };
        h =
          { host, ... }:
          {
            "${host.name}" = "x";
          };
      };
      run =
        nested: fn:
        yen.eval {
          imports = [
            (
              { yen, ... }:
              {
                yen.kinds.fleet = {
                  spawns.host = _: yen.host;
                  sinks.report = {
                    reduce = yen.lib.reduce.merge;
                    out =
                      { report, ... }:
                      {
                        inherit report;
                      };
                  };
                };
                yen.fleet.main = { };
                yen.aspects.report = {
                  at = if nested then yen.kinds.host.kinds.user else yen.kinds.user;
                  report = fns.${fn};
                };
              }
            )
            (
              if nested then
                {
                  yen.kinds.host.kinds.user = { };
                  yen.host.laptop.user.vic = { };
                  yen.host.laptop.user.ann = { };
                  yen.host.server.user.vic = { };
                }
              else
                (
                  { yen, ... }:
                  {
                    yen.kinds.host.spawns.user = _: yen.user;
                    yen.kinds.user = { };
                    yen.host.laptop = { };
                    yen.user.vic = { };
                    yen.user.ann = { };
                  }
                )
            )
          ];
        };
      rep = r: r.reduced.report."fleet:main" or null;
    in
    {
      hu-clean = eq (msgs (run true "hu")) [ ];
      hu = eq (rep (run true "hu")) {
        "laptop/ann" = "x";
        "laptop/vic" = "x";
        "server/vic" = "x";
      };
      u-clean = eq (msgs (run true "u")) [ ];
      u = eq (rep (run true "u")) {
        ann = "x";
        vic = "x";
      };
      h-clean = eq (msgs (run true "h")) [ ];
      h = eq (rep (run true "h")) {
        laptop = "x";
        server = "x";
      };
      # the flat twin (user a top kind the host spawns) gives the same rows for its one host
      flat-clean = eq (msgs (run false "hu")) [ ];
      flat-hu = eq (rep (run false "hu")) {
        "laptop/ann" = "x";
        "laptop/vic" = "x";
      };
      flat-u = eq (rep (run false "u")) (rep (run true "u"));
    };
  # c47: a sink declared on a nested kind is a key an aspect at that kind gives; an undeclared key stays an error
  nested-kinds-sinks =
    let
      nested =
        key:
        yen.eval (
          { yen, ... }:
          {
            yen.kinds.x.kinds.y.sinks.fw.reduce = yen.lib.reduce.list;
            yen.x.a.y.b = { };
            yen.aspects.p = {
              at = yen.kinds.x.kinds.y;
              ${key} = "on";
            };
          }
        );
      given = nested "fw";
    in
    {
      clean = eq given.errors [ ];
      reduced = eq given.reduced.fw."x:a/y:b" [ "on" ];
      undeclared = eq (map (e: e.code) (nested "zz").errors) [ "unknown-key" ];
    };
  # yen modules are not NixOS modules: a sink no module reads, or a key yen does not read, is an error
  unknown-keys =
    eq
      (map (e: { inherit (e) code from path; })
        (yen.eval {
          imports = [
            {
              options.x = 1;
              yen.kinds.host.feilds = { };
            }
            { yen.aspect.a = { }; }
          ];
        }).errors
      )
      ([
        {
          code = "unread-sink";
          from = "root/0";
          path = [ "options" ];
        }
        {
          code = "unknown-key";
          from = "root/1";
          path = [
            "yen"
            "aspect"
          ];
        }
        {
          code = "unknown-key";
          from = "root/0";
          path = [
            "yen"
            "kinds"
            "host"
            "feilds"
          ];
        }
      ]);
  # .21: a secret field never leaves the engine in an answer: facts, data, scopes, errors, the RDF export and the
  # seal state it by its hash, so a rule can still compare two secrets; an aspect still reads the value
  secrets-hidden =
    let
      fleet =
        extra:
        yen.eval (
          { yen, ... }:
          {
            imports = [ extra ];
            yen.kinds.top.spawns.host = _: yen.host;
            yen.kinds.host.fields.token = yen.lib.secret (yen.lib.is b.isString);
            yen.kinds.host.sinks.os = { };
            yen.top.t = { };
            yen.host.a.token = "hunter2";
            yen.aspects.login = {
              at = yen.kinds.host;
              os =
                { host, ... }:
                {
                  pw = host.token;
                };
            };
          }
        );
      clean = fleet { };
      shared = fleet (
        { yen, ... }:
        {
          yen.host.b.token = "hunter2";
          yen.host.c.token = 424242;
          yen.invariants.shared-token =
            {
              A,
              B,
              X,
            }:
            {
              bad = [
                A
                B
              ];
              pos = [
                (yen.facts.host.token A X)
                (yen.facts.host.token B X)
                (yen.facts.lt A B)
              ];
            };
        }
      );
      seen =
        r:
        b.toJSON {
          inherit (r) facts data errors;
          scopes = map (
            s:
            removeAttrs s [
              "parent"
              "up"
              "rup"
              "__here"
            ]
          ) r.scopes;
          agent = r.agent;
          export = (yen.rdf.share r).ntriples;
          seal = r.check.seal;
        };
      leaks = r: b.match ".*(hunter2|424242).*" (seen r) != null;
    in
    {
      t1 = eq (shared.check.violations) ([
        [
          "bad"
          "shared-token"
          "top:t/host:a"
          "top:t/host:b"
        ]
      ]);
      t2 = no (leaks shared);
      t3 = no (leaks clean);
      t4 = eq (clean.reduced.os."top:t/host:a") ([ { pw = "hunter2"; } ]);
    };
  r4-types =
    let
      rule =
        yen:
        { H, X }:
        {
          bad = H;
          pos = [ (yen.facts.host.tag H X) ];
          neg = [ (yen.relations.digits X) ];
        };
      run =
        rel:
        yen.eval (
          { yen, ... }:
          {
            yen.kinds.top.spawns.host = _: yen.host;
            yen.kinds.host.fields.tag = yen.lib.is (_: true);
            yen.top.t = { };
            yen.host = {
              a.tag = "b:1";
              "a:b".tag = "2";
            };
            yen.relations.digits = rel;
            yen.invariants.not-digits = rule yen;
          }
        );
      digits = s: b.match "[0-9]+" s != null;
      byType = run { type.check = digits; };
      byFn = run {
        arity = 1;
        holds = ts: digits (b.head ts);
      };
      broken = run {
        arity = 1;
        holds = ts: "yes";
      };
      bad = [
        [
          "bad"
          "not-digits"
          "top:t/host:a"
        ]
      ];
    in
    {
      t1 = eq (byType.check.violations) (bad);
      t2 = eq (byFn.check.violations) (bad);
      t3 = yes (codes broken != [ ]);
      t4 = yes (b.all (c: c == "external-not-bool") (codes broken));
      t5 = eq (builtins.attrNames broken.flake) ([ "invalid-flake-errors" ]);
    };
  # a field reads only the shape of a typed value; `result.deep` checks the parts after evaluation (lazy contracts)
  deep =
    let
      host =
        ports: run:
        yen.eval (
          { yen, ... }:
          {
            yen.kinds.host.fields = {
              ports = yen.lib.listOf (yen.lib.is b.isInt);
              run = yen.lib.functionTo (yen.lib.is b.isInt);
            };
            yen.host.web = { inherit ports run; };
          }
        );
      paths = r: map (e: e.path) r.deep;
      good = host [ 1 2 ] (x: x);
      bad = host [ 1 "x" 3 ] (x: x);
      # an element that throws when forced, and a function that throws when called
      throws = host [ 1 (throw "forced") ] (_: throw "called");
    in
    {
      good = eq (good.errors ++ good.deep) [ ];
      bad-errors = eq bad.errors [ ];
      bad-deep = eq (paths bad) [
        [
          "ports"
          "1"
        ]
      ];
      bad-code = eq (map (e: e.code) bad.deep) [ "deep" ];
      # nothing forces the element or calls the function while the fleet evaluates
      lazy = yes ((b.tryEval (b.deepSeq throws.errors true)).success);
      # the deep check forces the element: a throw is an error record, never a crash
      throw-data = eq (paths throws) [
        [
          "ports"
          "1"
        ]
      ];
      not-a-list = eq (map (e: e.code) (host "x" (x: x)).errors) [ "check" ];
      not-a-function = eq (map (e: e.code) (host [ ] 1).errors) [ "check" ];
      nested = eq (paths (host [ [ 1 ] ] (x: x))) [
        [
          "ports"
          "0"
        ]
      ];
      # a sink `of` a list: the module's value is a list, its elements are parts
      sink =
        eq
          (paths (
            yen.eval {
              imports = [
                { yen.sinks.nums.of = yen.listOf (yen.is b.isInt); }
                {
                  nums = [
                    1
                    "x"
                  ];
                }
              ];
            }
          ))
          [
            [
              "nums"
              "1"
            ]
          ];
    };
  # a kind owns aspects: by default on every scope of the kind, as nested kinds are spawned by default; an explicit
  # `at` replaces that default; nested kinds own theirs; a ref goes through the kind
  kind-aspects =
    let
      fleet =
        extra:
        yen.eval {
          imports = [
            (
              { yen, ... }:
              {
                yen.kinds.fleet = {
                  spawns.host = _: yen.host;
                  sinks.out.reduce = yen.lib.reduce.list;
                };
                yen.fleet.main = { };
                yen.kinds.host = {
                  fields.role = yen.lib.str;
                  aspects.ssh.out = { scope, ... }: [ "ssh@${scope.name}" ];
                  aspects.web = {
                    at = s: (s.role or null) == "web";
                    out = { scope, ... }: [ "web@${scope.name}" ];
                  };
                  kinds.user.aspects.shell.out = { scope, ... }: [ "shell@${scope.name}" ];
                };
                yen.host.a = {
                  role = "web";
                  user.vic = { };
                };
                yen.host.b.role = "db";
                yen.aspects.after = {
                  at = yen.kinds.host.aspects.web;
                  out = { scope, ... }: [ "after@${scope.name}" ];
                };
                yen.flake =
                  { out, ... }:
                  {
                    inherit out;
                  };
              }
            )
            extra
          ];
        };
      r = fleet { };
      out = b.concatLists r.flake.out;
      has = x: b.elem x out;
    in
    {
      errors = eq r.errors [ ];
      # default `at`: every host, and no other scope (the fleet scope has no `ssh`)
      default = eq (b.filter (x: b.substring 0 4 x == "ssh@") out) [
        "ssh@a"
        "ssh@b"
      ];
      explicit = yes (has "web@a" && !(has "web@b"));
      nested = eq (b.filter (x: b.substring 0 6 x == "shell@") out) [ "shell@vic" ];
      ref = yes (has "after@a" && !(has "after@b"));
      not-attrs = eq (map (e: e.code) (fleet { yen.kinds.host.aspects = 5; }).errors) [ "not-a-kind" ];
      aspect-not-attrs = eq (map (e: e.code) (fleet { yen.kinds.host.aspects.x = 5; }).errors) [
        "not-a-kind"
      ];
    };
  # #87: an instance owns aspects, `yen.<kind>.<name>.aspects.<a>`, keyed by its declaration path; no fleet name can take it
  owned-aspects =
    let
      key = b.toJSON [
        "kit"
        "disko"
        "aspects"
        "default"
      ];
      fleet =
        extra:
        yen.eval {
          imports = [
            (
              { yen, ... }:
              {
                yen.kinds.top = {
                  spawns.kit = _: yen.kit;
                  sinks.out.reduce = yen.lib.reduce.list;
                };
                yen.top.t = { };
                yen.kinds.kit = { };
                yen.kit.disko.aspects.default.at = yen.kinds.kit;
                # a fleet aspect gated by the kit's aspect, through the instance
                yen.aspects.after = {
                  at = yen.kit.disko.aspects.default;
                  out = { scope, ... }: [ scope.name ];
                };
                yen.flake =
                  { out, ... }:
                  {
                    inherit out;
                  };
              }
            )
            extra
          ];
        };
      r = fleet { };
    in
    {
      id = yes (r.agent.schema.aspects ? ${key});
      ref = eq r.flake.out [ [ "disko" ] ];
      data = eq r.data.kit.disko { };
      errors = eq r.errors [ ];
      file = yes (
        r.declaredIn [
          "aspects"
          key
        ] != [ ]
      );
      reserved = eq (map (e: e.code) (fleet { yen.aspects.${key} = { }; }).errors) [ "reserved" ];
    };
  # #80: a `sinks` or a sink that is no attrset is an error record, never a Nix throw
  kind-sinks-not-attrs =
    let
      codes =
        sinks:
        map (e: e.code)
          (yen.eval {
            yen.kinds.fleet = { inherit sinks; };
            yen.fleet.main = { };
          }).errors;
    in
    {
      whole = eq (codes 5) [ "not-a-kind" ];
      one = eq (codes { out = 5; }) [ "not-a-kind" ];
      good = eq (codes { out.reduce = yen.reduce.list; }) [ ];
    };
  # #81: a stored query param named `at` keeps its type, as any other param
  query-param-at =
    eq
      (yen.eval (
        { yen, ... }:
        {
          yen.kinds.x = { };
          yen.queries.typed = {
            params = {
              at = yen.kinds.x;
              other = yen.kinds.x;
            };
            answer = _: 1;
          };
        }
      )).queries.typed.types
      {
        at = "a x ref";
        other = "a x ref";
      };
  # a value one of the types accepts: a string or an int pass, a bool is neither
  one-of =
    let
      t = yen.listOf (
        yen.oneOf [
          yen.str
          yen.int
        ]
      );
      inherit (self._core.types) checkOf;
    in
    {
      both = yes (
        checkOf t [
          "a"
          1
        ]
      );
      neither = no (checkOf t [ true ]);
    };
  # a type whose check gives no bool (a curried gen-types check) is an error record, never a throw
  check-not-bool =
    let
      r = yen.eval (
        { yen, ... }:
        {
          yen.kinds.top.spawns.host = _: yen.host;
          yen.host.a.w = 1;
          yen.kinds.host.fields.w.check = v: (_: true);
          yen.top.t = { };
        }
      );
    in
    eq (codes r) ([ "check-not-bool" ]);
  presence-spawns = {
    t1 = eq (ids presence) ([
      "top:t"
      "top:t/host:a"
      "top:t/host:a/svc:web"
      "top:t/host:b"
    ]);
    t2 = eq (msgs presence) ([ ]);
  };
  gap-derived-default = {
    t1 = eq ((b.head (b.filter (s: s.name == "h1") gaps.scopes)).vpn) ("vpn-h1");
    t2 = eq ((b.head (b.filter (s: s.name == "h2") gaps.scopes)).vpn) ("custom");
  };
}
