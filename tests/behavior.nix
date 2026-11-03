# The behavior oracles of the engine: tests.behavior.<test> = { expr; expected; }. Run them: fastest --flake .#tests behavior
self:
let
  inherit (self.tests._shared)
    argsDown
    argsInImports
    argsMissing
    argsSibling
    argsTwo
    argsTyped
    b
    configLike
    deep
    diamond
    eq
    fleet
    gaps
    gapsBadAt
    good
    has
    hostOf
    ids
    importsLoop
    importsRead
    logic
    msgs
    no
    ordered
    q5
    sinkArgs
    treeAll
    treeAllWith
    treeHit
    wide
    yen
    yes
    ;
in
{
  # flat joins list elements and keeps scalars; the first of a duplicate stays, so the order is the order of arrival
  reduce-flat =
    eq
      (yen.reduce.flat (
        map (value: { inherit value; }) [
          [
            1
            2
          ]
          3
          [
            2
            4
          ]
          [ ]
          1
        ]
      ))
      {
        value = [
          1
          2
          3
          4
        ];
        errors = [ ];
      };
  reduce-flat-empty = eq (yen.reduce.flat [ ]) {
    value = [ ];
    errors = [ ];
  };
  # reduce errors name their receiver and sink: a strategy cannot know them, the engine sets them
  reduce-error-receiver =
    let
      r = yen.eval (
        { yen, ... }:
        {
          yen.kinds.top = {
            spawns.h = _: yen.h;
          };
          yen.kinds.h.sinks.admin.reduce = yen.lib.reduce.one;
          yen.top.t = { };
          yen.h.a = { };
          yen.aspects.x = {
            at = yen.kinds.h;
            admin = "ana";
          };
          yen.aspects.y = {
            at = yen.kinds.h;
            admin = "bo";
          };
        }
      );
    in
    eq (b.map (e: { inherit (e) code from sink; }) r.errors) [
      {
        code = "one";
        from = "top:t/h:a";
        sink = "admin";
      }
    ];
  # an aspect's `errors` key gives records too; `from` is always the giving scope
  aspect-error-record =
    let
      r = yen.eval (
        { yen, ... }:
        {
          yen.kinds.top = {
            spawns.h = _: yen.h;
          };
          yen.kinds.h = { };
          yen.top.t = { };
          yen.h.a = { };
          yen.aspects.x = {
            at = yen.kinds.h;
            errors = [
              {
                code = "dup-addr";
                error = "two hosts at 10.0.0.1";
                fix = "change one";
                from = "forged";
              }
              "plain message"
            ];
          };
        }
      );
    in
    {
      records =
        eq
          (b.map (e: {
            inherit (e)
              code
              error
              from
              class
              ;
          }) r.errors)
          [
            {
              code = "dup-addr";
              error = "two hosts at 10.0.0.1";
              from = "top:t/h:a";
              class = "fixable";
            }
            {
              code = "error";
              error = "plain message";
              from = "top:t/h:a";
              class = "fixable";
            }
          ];
      fix = eq (b.head r.errors).fix "change one";
    };
  not-cycle-undefined =
    let
      r = logic true;
      h = "top:t/host:h";
    in
    {
      t1 = eq (map (x: "${x.aspect}@${x.scope}") r.undefined) ([
        "a@${h}"
        "b@${h}"
        "c@${h}"
        "v@${h}"
        "w@${h}/user:u"
      ]); # within and below carry it across scopes
      t2 = no (r.active.a.${h});
      t3 = no (r.active.b.${h});
      t4 = no (r.active.c.${h});
      t5 = eq (msgs r) ([ ]);
    };
  not-cycle-control =
    let
      r = logic false;
      h = "top:t/host:h";
    in
    {
      t1 = eq (r.undefined) ([ ]);
      t2 = no (r.active.a.${h});
      t3 = yes (r.active.b.${h});
      t4 = yes (r.active.c.${h});
    };
  positive-cycle-false =
    let
      r = logic true;
    in
    {
      t1 = no (r.active.p."top:t/host:h");
      t2 = no (b.any (x: x.aspect == "p" || x.aspect == "q") r.undefined);
    };
  within-below-no-cycle =
    let
      r = logic false;
    in
    {
      t1 = yes (r.active.w."top:t/host:h/user:u");
      t2 = yes (r.active.v."top:t/host:h");
    };
  diamond-memo = yes (diamond 60).active.x60."top:t/host:h";
  good-no-errors = eq (msgs good) ([ ]);
  good-persist = eq (good.reduced.persist."fleet:main/host:lb") ([ "/var/lib/motd" ]);
  good-flake = eq (good.flake.nixosConfigurations.lb) ([
    { environment.etc.motd.text = "/var/lib/motd"; }
  ]);
  order-default = eq (ids (ordered 0)) ([
    "fleet:main"
    "fleet:main/host:a"
    "fleet:main/host:b"
    "fleet:main/host:c"
  ]);
  order-first = eq (ids (ordered (-1))) ([
    "fleet:main"
    "fleet:main/host:c"
    "fleet:main/host:a"
    "fleet:main/host:b"
  ]);
  order-bad = yes (has (ordered "x") "order is not a number");
  q5-required = yes (has (q5 ({ cluster, ... }: { })) "aspect k3s: arg `cluster` has no answer");
  q5-optional = no (
    (b.any (m: b.match ".*arg `cluster`.*" m != null) (
      msgs (
        q5 (
          {
            cluster ? null,
            ...
          }:
          { }
        )
      )
    ))
  );
  q5-emitted = yes (
    has (q5 (
      {
        cluster ? null,
        ...
      }:
      { }
    )) "no cluster: k3s off"
  );
  cycle-many-elements =
    eq
      ((yen.eval (
        { yen, ... }:
        {
          yen.kinds.top = {
            spawns = { };
            sinks.many.reduce = yen.lib.reduce.list;
          };
          yen.top.t = { };
          yen.aspects.m = {
            at = yen.kinds.top;
            cycle = _: {
              many = [
                "a"
                "b"
                "c"
              ];
            };
          };
        }
      )).reduced.many."top:t"
      )
      ([
        "a"
        "b"
        "c"
      ]);
  tree-nearest = {
    t1 = eq (treeHit.reduced.seen."top:t/cluster:c1/node:n1" or null) ([ "c1" ]);
    t2 = eq (map (e: e.error) treeHit.errors) ([ ]);
  };
  tree-requests = {
    t1 = eq (treeAll.reduced.seen."top:t/cluster:c1/node:n1") ([
      {
        parent = [ "top:t/cluster:c1" ];
        none = [ ];
        kids = [
          [
            "p1"
            "p2"
          ]
        ];
        same = [ [ "top:t/cluster:c1" ] ];
        holds = [ true ];
        all = [ [ "c1" ] ];
        bad = [ ];
      }
    ]);
    t2 = eq (treeAll.errors) ([ ]);
    t3 = eq (map (e: e.code) (treeAllWith true).errors) ([ "tree-request" ]);
    t4 = eq ((treeAllWith true).reduced) (null);
  };
  # NixOS `config` parity (configLike): each test is one pattern a fixpoint `config` expresses
  config-no-errors = eq (msgs configLike) ([ ]);
  config-aggregate = eq (configLike.reduced.ports."fleet:main/host:b") ([ 22 ]);
  config-mkif = eq (b.sort b.lessThan configLike.reduced.ports."fleet:main/host:a") ([
    22
    80
    443
  ]);
  config-read-option = eq (configLike.reduced.firewall."fleet:main/host:a") ([
    22
    80
    443
  ]);
  config-default-from-config = eq ((hostOf configLike).fqdn) ("a.lan");
  config-lazy-chain = eq (configLike.reduced.chain."fleet:main/host:a") (20);
  config-deep-merge = eq (configLike.reduced.settings."fleet:main/host:b") ({
    a = 1;
    b.c = 2;
  });
  config-priority = {
    t1 = eq (configLike.reduced.motd."fleet:main/host:a") ("default");
    t2 = eq (configLike.reduced.motd."fleet:main/host:b") ("forced");
  };
  config-other-node = eq configLike.reduced.peers."fleet:main/host:a" { b = "10.0.0.2"; };
  # an element asks the tree for the children of its scope: a `children` request, never `yen.lib.children`
  lib-children =
    eq
      ((yen.eval (
        { yen, ... }:
        {
          yen.kinds.top = {
            spawns.host = _: {
              b = { };
              a = { };
            };
            sinks.kids = { };
          };
          yen.kinds.host = { };
          yen.top.t = { };
          yen.aspects.k = {
            at = yen.kinds.top;
            cycle =
              { tree, ... }:
              let
                kids.children = yen.kinds.host;
              in
              {
                tree = [ kids ];
                kids = [ (map (c: c.name) (b.head (tree.select kids))) ];
              };
          };
        }
      )).reduced.kids."top:t"
      )
      ([
        [
          "a"
          "b"
        ]
      ]);
  # a spawn by a ref field: one ref or a list that holds the scope; a missing field or another scope is no child
  lib-pointing =
    eq
      (map (s: s.id)
        (yen.eval (
          { yen, ... }:
          {
            yen.kinds.host = {
              spawns.user = yen.lib.pointing "hosts" yen.user;
              spawns.guest = yen.lib.pointing "on" yen.guest;
            };
            yen.kinds.user.fields.hosts = yen.lib.listOf yen.kinds.host;
            yen.kinds.guest.fields.on = yen.kinds.host;
            yen.host = {
              a = { };
              b = { };
            };
            yen.user = {
              both.hosts = [
                yen.host.a
                yen.host.b
              ];
              onlyB.hosts = [ yen.host.b ];
              none = { };
            };
            yen.guest.g.on = yen.host.a;
          }
        )).scopes
      )
      [
        "host:a"
        "host:a/guest:g"
        "host:a/user:both"
        "host:b"
        "host:b/user:both"
        "host:b/user:onlyB"
      ];
  lib-children-refused =
    eq
      (b.tryEval (
        b.deepSeq
          (yen.eval (
            { yen, ... }:
            {
              yen.kinds.top = {
                spawns.host = _: {
                  b = { };
                  a = { };
                };
                sinks.kids = { };
              };
              yen.kinds.host = { };
              yen.top.t = { };
              yen.aspects.k = {
                at = yen.kinds.top;
                kids = { scope, ... }: map (c: c.name) (yen.lib.children yen.kinds.host scope);
              };
            }
          )).reduced.kids
          true
      )).success
      false;
  aspect-key-no-sink = eq (msgs (
    yen.eval {
      imports = [
        (fleet { addr = "a"; })
        { yen.aspects.motd.nixso = { }; }
      ];
    }
  )) [ "`nixso` is not a key yen reads here" ];
  args-source = {
    addr = eq (hostOf argsDown).addr "hi";
    errors = eq (msgs argsDown) [ ];
  };
  args-missing = yes (has argsMissing "module root/0: arg `nope` has no answer");
  args-sibling = {
    addr = eq (hostOf argsSibling).addr "xy";
    errors = eq (msgs argsSibling) [ ];
  };
  args-in-imports = eq (map (e: { inherit (e) code error; }) argsInImports.errors) [
    {
      code = "module";
      error = "module root/1: its keys read an arg";
    }
  ];
  # the loader as data: what each module asks, gives, declares, and which module imports it
  imports-modules = eq importsRead.modules."root/1" {
    parent = "root";
    asks = [ "more" ];
    gives = [ ];
    declares = [ ];
    importer = true;
  };
  # mkFlake sinks module: each key of `sinks` is a module sink, declared for you
  mkflake-sinks = eq (yen.mkFlake { greeting = "hi"; } (
    { greeting, ... }:
    {
      yen.kinds.world.spawns = { };
      yen.world.earth = { };
      yen.flake.hello = greeting;
    }
  )) { hello = "hi"; };
  imports-read = {
    addr = eq (hostOf importsRead).addr "kit";
    errors = eq (msgs importsRead) [ ];
  };
  imports-loop = eq (map (e: { inherit (e) code error path; }) importsLoop.errors) [
    {
      code = "import-loop";
      error = "module root/0: `imports` reads a sink that its own imports give";
      path = [ "cfg" ];
    }
  ];
  args-two-givers = eq (map (e: { inherit (e) code sink; }) argsTwo.errors) [
    {
      code = "one";
      sink = "cfg";
    }
  ];
  args-typed = {
    addr = eq (hostOf argsTyped).addr "a,b";
    errors = eq (map (e: { inherit (e) code from path; }) argsTyped.errors) [
      {
        code = "of";
        from = "root/1";
        path = [ "port" ];
      }
      {
        code = "unknown-key";
        from = "root/0";
        path = [
          "yen"
          "sinks"
          "bad"
          "tpye"
        ];
      }
    ];
  };
  args-unread =
    eq
      (map (e: { inherit (e) code from near; })
        (yen.eval {
          greting = "hi";
          imports = [
            (
              {
                greeting ? "",
                ...
              }:
              { }
            )
          ];
        }).errors
      )
      [
        {
          code = "unread-sink";
          from = "root";
          near = [ "greeting" ];
        }
      ];
  gap-multi-file-functions = {
    t1 = eq (gaps.reduced.nixos."fleet:main/host:h1") ([
      [ "a-h1" ]
      [ "b-h1" ]
      "marker"
    ]);
    t2 = no ((has gaps "two answers for aspects.multi.nixos"));
  };
  sink-arg-element-per-receiver = {
    t1 = eq (sinkArgs.reduced.seen."fleet:main") ([
      "prod"
      "staging"
    ]);
    t2 = eq (msgs sinkArgs) ([ ]); # a and c read one tag: once
  };
  gap-static-once-per-receiver = eq (b.length (
    b.filter (v: v == "marker") gaps.reduced.nixos."fleet:main/host:h1"
  )) (1);
  gap-bad-at = yes (has gapsBadAt "`at` holds a string, not a predicate");
  deep-1000 = eq (b.length (deep 1000).scopes) (1002);
  empty-fleet = {
    t1 = eq (msgs (yen.eval { })) ([ ]);
    t2 = eq ((yen.eval { }).scopes) ([ ]);
    t3 = eq ((yen.eval { }).flake) (null); # den-hoag empty-aspects
  };
  wide-3000 = eq (b.length (wide 3000).scopes) (3001);
}
