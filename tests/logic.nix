# The logic oracles of the engine: tests.logic.<test> = { expr; expected; }. Run them: fastest --flake .#tests logic
self:
let
  inherit (self.tests._shared)
    b
    choice
    D
    eq
    K
    yen
    ;

  G = yen.graphs;
  ring = {
    a = [ "b" ];
    b = [ "c" ];
    c = [ "a" ];
    d = [ "a" ];
  };
  dag = {
    app = [
      "db"
      "cache"
    ];
    cache = [ "net" ];
    db = [ "net" ];
    net = [ ];
  };

in
{
  graphs-reach = {
    app = eq (G.reach dag "app") [
      "cache"
      "db"
      "net"
    ];
    net = eq (G.reach dag "net") [ ];
    reachers = eq (G.reachers dag "net") [
      "app"
      "cache"
      "db"
    ];
  };
  graphs-topo = {
    dag = eq (G.topo dag) {
      ok = true;
      order = [
        "net"
        "cache"
        "db"
        "app"
      ];
      stuck = [ ];
    };
    ring-ok = eq (G.topo ring).ok false;
    ring-stuck = eq (G.topo ring).stuck [
      "a"
      "b"
      "c"
      "d"
    ];
  };
  graphs-layers = eq (G.layers dag) [
    [ "net" ]
    [
      "cache"
      "db"
    ]
    [ "app" ]
  ];
  graphs-cycles = {
    ring = eq (G.cycles ring) [
      "a"
      "b"
      "c"
    ];
    dag = eq (G.cycles dag) [ ];
    sccs = eq (G.sccs ring) [
      [
        "a"
        "b"
        "c"
      ]
    ];
  };
  graphs-paths = {
    shortest = eq (G.shortest ring "d" "c") [
      "d"
      "a"
      "b"
      "c"
    ];
    none = eq (G.shortest dag "net" "app") null;
    paths = eq (G.paths dag "app" "net") [
      [
        "app"
        "cache"
        "net"
      ]
      [
        "app"
        "db"
        "net"
      ]
    ];
  };
  # a graph over refs: G.of nodes next; every answer is a node identity { kind; name; }, never a name string
  graphs-refs =
    let
      r = yen.eval (
        { yen, ... }:
        {
          yen.kinds.top.spawns.host = _: yen.host;
          yen.kinds.host.fields.dependsOn = yen.lib.opt (yen.lib.listOf yen.kinds.host) [ ];
          yen.top.t = { };
          yen.host = {
            db = { };
            lb.dependsOn = [ yen.host.web ];
            web.dependsOn = [ yen.host.db ];
          };
          yen.flake =
            { ... }:
            let
              g = G.of (b.attrValues yen.host) (h: h.dependsOn);
            in
            {
              layers = G.layers g;
              reach = G.reach g yen.host.lb;
              reachers = G.reachers g yen.host.db;
              shortest = G.shortest g yen.host.lb yen.host.db;
              topo = (G.topo g).order;
              transposed = G.reach (G.transpose g) yen.host.db;
              none = G.shortest g yen.host.db yen.host.lb;
            };
        }
      );
      h = name: {
        kind = "host";
        inherit name;
      };
    in
    {
      layers = eq r.flake.layers [
        [ (h "db") ]
        [ (h "web") ]
        [ (h "lb") ]
      ];
      reach = eq r.flake.reach [
        (h "db")
        (h "web")
      ];
      reachers = eq r.flake.reachers [
        (h "lb")
        (h "web")
      ];
      shortest = eq r.flake.shortest [
        (h "lb")
        (h "web")
        (h "db")
      ];
      topo = eq r.flake.topo [
        (h "db")
        (h "web")
        (h "lb")
      ];
      transposed = eq r.flake.transposed [
        (h "lb")
        (h "web")
      ];
      none = eq r.flake.none null;
    };
  datalog-wfs =
    let
      w = D.wfs choice;
    in
    {
      true = eq w.true [ "s" ];
      undefined = eq w.undefined [
        "a"
        "b"
        "c"
      ];
      false = eq w.false [
        "t"
        "u"
      ];
    };
  datalog-stratified =
    let
      w = D.wfs (choice ++ [ { head = "b"; } ]);
    in
    {
      true = eq w.true [
        "b"
        "s"
      ];
      undefined = eq w.undefined [ ];
      false = eq w.false [
        "a"
        "c"
        "t"
        "u"
      ];
    };
  datalog-stable = {
    choice = eq (D.stable choice) [
      [
        "b"
        "s"
      ]
      [
        "a"
        "c"
        "s"
      ]
    ];
    none = eq (D.stable [
      {
        head = "p";
        neg = [ "p" ];
      }
    ]) [ ];
  };
  datalog-why = {
    s = eq (D.why choice (D.wfs choice) "s") [ { head = "s"; } ];
    t = eq (D.why choice (D.wfs choice) "t") [ ];
  };
  # ground rules by reference: relations from yen.relations, terms are instances; no name is written as a string
  datalog-refs =
    let
      r = yen.eval (
        { yen, ... }:
        {
          yen.kinds.top.spawns.host = _: yen.host;
          yen.kinds.host.fields.web = yen.lib.opt (yen.lib.is b.isBool) false;
          yen.top.t = { };
          yen.host = {
            a.web = true;
            c = { };
          };
          yen.relations = {
            web.arity = 1;
            serves.arity = 1;
          };
          yen.flake =
            { ... }:
            let
              inherit (yen.relations) web serves;
              hosts = b.attrValues yen.host;
              rules =
                map (h: {
                  head = serves h;
                  pos = [ (web h) ];
                }) hosts
                ++ map (h: { head = web h; }) (b.filter (h: h.web) hosts);
              m = yen.lib.datalog.wfs rules;
            in
            {
              serves = map (h: h.name) (b.filter (h: m.holds (serves h)) hosts);
              whyNot = map (x: x.missing) (yen.lib.datalog.whyNot rules m (serves yen.host.c));
              why = b.length (yen.lib.datalog.why rules m (serves yen.host.a));
              # an instance term is its identity: the same atom whatever its data
              atom = yen.lib.datalog.atom (serves yen.host.a);
            };
        }
      );
    in
    {
      serves = eq r.flake.serves [ "a" ];
      why = eq r.flake.why 1;
      why-not = eq r.flake.whyNot [
        [
          [
            "web"
            {
              kind = "host";
              name = "c";
            }
          ]
        ]
      ];
      atom = eq r.flake.atom [
        "serves"
        {
          kind = "host";
          name = "a";
        }
      ];
    };
  uKanren-backward = {
    t1 =
      eq
        (map (map K.toList) (
          K.runAll (
            q:
            K.fresh (
              { a, b }:
              [
                (K.appendo a b (
                  K.fromList [
                    1
                    2
                  ]
                ))
                (K.eq q [
                  a
                  b
                ])
              ]
            )
          )
        ))
        ([
          [
            [ ]
            [
              1
              2
            ]
          ]
          [
            [ 1 ]
            [ 2 ]
          ]
          [
            [
              1
              2
            ]
            [ ]
          ]
        ]);
    t2 =
      eq
        (map K.toList (
          K.run 1 (
            q:
            K.appendo (K.fromList [ 1 ]) (K.fromList [
              2
              3
            ]) q
          )
        ))
        ([
          [
            1
            2
            3
          ]
        ]);
  };
  uKanren-unify-records = {
    t1 =
      eq
        (K.runAll (
          q:
          K.fresh (
            { x }:
            [
              (K.eq q {
                addr = x;
                port = 443;
              })
              (K.membero x [
                "10.0.1.1"
                "10.0.1.2"
              ])
            ]
          )
        ))
        ([
          {
            addr = "10.0.1.1";
            port = 443;
          }
          {
            addr = "10.0.1.2";
            port = 443;
          }
        ]);
    t2 = eq (K.runAll (q: K.eq { a = q; } { b = 1; })) ([ ]);
    t3 = eq (K.runAll (q: K.eq [ q 1 ] [ 2 3 ])) ([ ]);
    t4 = eq (K.runAll (
      q:
      K.eq
        {
          addr = q;
          port = 443;
        }
        {
          addr = "10.0.1.1";
          port = 443;
        }
    )) ([ "10.0.1.1" ]); # record against record
  };
  uKanren-fresh-occurs = {
    t1 =
      eq
        (K.run 1 (
          q:
          K.fresh (
            { x }:
            K.eq q [
              x
              x
            ]
          )
        ))
        ([
          [
            "_.0"
            "_.0"
          ]
        ]);
    t2 = eq (K.run 1 (q: K.eq q [ q ])) ([ ]);
  };
  # #106: `{ x, y, ... }:` names the query variables, as a datalog rule does; the answer has one value per name
  uKanren-named-query = {
    t1 =
      eq
        (K.run 1 (
          { x, y }:
          [
            (K.eq x 1)
            (K.eq y [ x ])
          ]
        ))
        [
          {
            x = 1;
            y = [ 1 ];
          }
        ];
    t2 = eq (K.run 1 ({ x, y }: K.eq x 2)) [
      {
        x = 2;
        y = "_.0";
      }
    ];
    t3 =
      eq
        (K.runAllFuel 100 (
          { x, y }:
          K.fresh (
            { z }:
            [
              (K.membero x [
                1
                2
              ])
              (K.eq y x)
            ]
          )
        )).answers
        [
          {
            x = 1;
            y = 1;
          }
          {
            x = 2;
            y = 2;
          }
        ];
  };
  uKanren-interleave =
    let
      fives =
        x:
        K.disj [
          (K.eq x 5)
          (fives x)
        ];
      sixes =
        x:
        K.disj [
          (K.eq x 6)
          (sixes x)
        ];
    in
    eq
      (K.run 4 (
        q:
        K.disj [
          (fives q)
          (sixes q)
        ]
      ))
      ([
        5
        6
        5
        6
      ]);
  uKanren-cons-unbounded = {
    t1 = eq (K.run 3 (q: K.fresh ({ x, y }: [ (K.appendo x y q) ]))) ([
      "_.0"
      {
        head = "_.0";
        tail = "_.1";
      }
      {
        head = "_.0";
        tail = {
          head = "_.1";
          tail = "_.2";
        };
      }
    ]);
    t2 =
      eq
        (K.run 2 (
          q:
          K.membero q (
            K.fromList [
              "x"
              "y"
            ]
          )
        ))
        ([
          "x"
          "y"
        ]);
  };
  uKanren-neq-store = {
    t1 =
      eq
        (K.runAll (q: [
          (K.neq q 1)
          (K.membero q [
            1
            2
            3
          ])
        ]))
        ([
          2
          3
        ]); # =/= before the value: stored
    t2 = eq (K.runAll (
      q:
      K.fresh (
        { a }:
        [
          (K.neq q { p = 1; })
          (K.eq q { p = a; })
          (K.membero a [
            1
            2
          ])
        ]
      )
    )) ([ { p = 2; } ]);
    t3 = eq (K.runC 1 (q: K.fresh ({ x }: [ (K.neq q x) ]))) ([
      {
        value = "_.0";
        neq = [
          [
            [
              "_.0"
              "_.1"
            ]
          ]
        ];
        dom = { };
      }
    ]);
    t4 = eq (K.runAll (q: [
      (K.neq q 1)
      (K.eq q 1)
    ])) ([ ]);
  };
  uKanren-fd = {
    t1 =
      eq
        (K.runAll (
          q:
          K.fresh (
            { x, y }:
            [
              (K.infd [ x y ] 1 4)
              (K.plusfd x y 5)
              (K.eq q [
                x
                y
              ])
              (K.label [
                x
                y
              ])
            ]
          )
        ))
        ([
          [
            1
            4
          ]
          [
            2
            3
          ]
          [
            3
            2
          ]
          [
            4
            1
          ]
        ]);
    t2 =
      eq
        (K.runAll (
          q:
          K.fresh (
            {
              a,
              b,
              c,
            }:
            [
              (K.infd [ a b c ] 1 3)
              (K.distinctfd [
                a
                b
                c
              ])
              (K.ltfd a b)
              (K.eq q [
                a
                b
                c
              ])
              (K.label [
                a
                b
                c
              ])
            ]
          )
        ))
        ([
          [
            2
            3
            1
          ]
          [
            1
            2
            3
          ]
          [
            1
            3
            2
          ]
        ]);
    t3 =
      eq
        (K.runC 1 (q: [
          (K.infd [ q ] 2 5)
          (K.neqfd q 3)
        ]))
        ([
          {
            value = "_.0";
            neq = [ ];
            dom = {
              "_.0" = [
                2
                4
                5
              ];
            };
          }
        ]);
    t4 = eq (K.runAll (q: [
      (K.infd [ q ] 1 3)
      (K.lefd 5 q)
    ])) ([ ]); # propagation alone fails it
    t5 = eq (K.runAll (q: [
      (K.infd [ q ] 1 3)
      (K.eq q 7)
    ])) ([ ]);
    t6 = eq (K.runAll (q: [
      (K.eq q 2)
      (K.infd [ q ] 1 3)
    ])) ([ 2 ]); # a bound value meets its domain
    t7 =
      eq
        (map (a: a.dom) (
          K.runC 1 (
            q:
            K.fresh (
              { x, y }:
              [
                (K.infd [ x y ] 1 3)
                (K.plusfd x y q)
                (K.infd [ q ] 0 99)
              ]
            )
          )
        ))
        ([
          {
            "_.0" = [
              2
              3
              4
              5
              6
            ];
          }
        ]); # the sum is bounded
  };
  uKanren-neq =
    eq
      (K.runAll (
        q:
        K.fresh (
          { a, b }:
          [
            (K.membero a [
              "x"
              "y"
            ])
            (K.membero b [
              "x"
              "y"
            ])
            (K.neq a b)
            (K.eq q [
              a
              b
            ])
          ]
        )
      ))
      ([
        [
          "x"
          "y"
        ]
        [
          "y"
          "x"
        ]
      ]);
}
