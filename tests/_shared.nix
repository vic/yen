# The fixtures and helpers the engine suites share: each suite inherits what it reads from `self.tests._shared`.
self:
let
  yen = self.api;
  b = builtins;
  # a fastest test: { expr; expected; }
  eq = expr: expected: { inherit expr expected; };
  yes = x: eq x true;
  no = x: eq x false;
  msgs = r: map (e: e.error) r.errors;
  has = r: m: b.elem m (msgs r);

  # the design §1 fleet; nixosSystem replaced by the module list
  fleet =
    extra:
    { yen, ... }:
    {
      yen.kinds.fleet = {
        spawns.host = _: yen.host;
        sinks.out.reduce = yen.lib.reduce.merge;
      };
      yen.kinds.host = {
        fields.addr = yen.lib.is b.isString;
        sinks.persist.reduce = yen.lib.reduce.set;
        sinks.nixos.out =
          { host, nixos, ... }:
          {
            nixosConfigurations.${host.name} = nixos;
          };
      };
      yen.fleet.main = { };
      yen.host.lb = extra;
      yen.aspects.motd = {
        at = yen.kinds.host;
        persist = "/var/lib/motd";
        nixos =
          { persist, ... }:
          {
            environment.etc.motd.text = b.concatStringsSep "\n" persist;
          };
      };
      yen.flake = { out, ... }: out;
    };
  good = yen.eval (fleet {
    addr = "10.0.1.1";
  });
  noAddr = yen.eval (fleet { });

  # §4: two feature files, types at two paths of one field; no merge
  settings = [
    (
      { yen, ... }:
      {
        yen.kinds.host.fields.settings.zfs.arcMax = yen.lib.maybe (yen.lib.is b.isInt);
      }
    )
    (
      { yen, ... }:
      {
        yen.kinds.host.fields.settings.k3s.role = yen.lib.opt (yen.lib.is b.isString) "agent";
      }
    )
  ];
  feat = data: yen.eval { imports = [ (fleet ({ addr = "a"; } // data)) ] ++ settings; };
  featLazy = yen.eval {
    imports = [
      (fleet { addr = "a"; })
      (
        { yen, ... }:
        {
          yen.kinds.host.fields.settings.lazy = yen.lib.opt (yen.lib.is b.isString) (throw "touched");
        }
      )
    ]
    ++ settings;
  };
  hostOf = r: b.head (b.filter (s: s.kind == "host") r.scopes);

  # §5: order is a sink; siblings by (order, key), parent first
  ordered =
    o:
    yen.eval (
      { yen, ... }:
      {
        yen.kinds.fleet.spawns.host = _: yen.host;
        yen.kinds.host = { };
        yen.fleet.main = { };
        yen.host = {
          a = { };
          b = { };
          c = { };
        };
        yen.aspects.c-first = {
          at = yen.host.c;
          order = o;
        };
      }
    );
  ids = r: map (s: s.id) r.scopes;

  # Q5: an arg nobody answers; the component may emit on `errors`
  q5 =
    arg:
    yen.eval (
      { yen, ... }:
      {
        imports = [ (fleet { addr = "a"; }) ];
        yen.kinds.cluster = { };
        yen.aspects.k3s = {
          at = yen.kinds.host;
          nixos = arg;
        };
        yen.aspects.warn = {
          at = yen.kinds.host;
          cycle =
            { tree, ... }:
            let
              c.nearest = yen.kinds.cluster;
            in
            {
              tree = [ c ];
              errors = if tree.select c == [ ] then [ "no cluster: k3s off" ] else [ ];
            };
        };
      }
    );

  # imports nest; a key is a sink, an arg is a source, from any module
  argsDown = yen.eval {
    greeting = "hi";
    imports = [
      {
        imports = [
          (
            { yen, greeting, ... }:
            {
              imports = [ (fleet { addr = greeting; }) ];
            }
          )
        ];
      }
    ];
  };
  argsMissing = yen.eval { imports = [ ({ nope, ... }: { }) ]; };
  # a sibling answers. `cfg` is declared with `reduce.merge`: two modules give it; `lib` has one giver
  chanLib = {
    id = x: x;
  };
  argsSibling = yen.eval {
    imports = [
      {
        cfg.a = "x";
        lib = chanLib;
      }
      (
        { yen, ... }:
        {
          cfg.b = "y";
          yen.sinks.cfg.reduce = yen.lib.reduce.merge;
        }
      )
      (
        { cfg, lib, ... }:
        {
          imports = [ (fleet { addr = lib.id (cfg.a + cfg.b); }) ];
        }
      )
    ];
  };
  # key names load before any source: reading an arg there is an error, not a loop.
  # `imports` may read a sink that modules outside its own imports give
  argsInImports = yen.eval {
    greeting = "hi";
    imports = [
      (
        { greeting, ... }:
        {
          imports = if greeting == "hi" then [ ] else [ ];
        }
      )
      (
        { greeting, ... }:
        {
          ${greeting} = 1;
        }
      )
    ];
  };
  # a kit from `inputs`, and a chain: the kit gives `more`, which another module imports (two rounds)
  importsRead = yen.eval {
    inputs.kit = {
      more = fleet { addr = "kit"; };
      yen.sinks.more = { };
    };
    yen.sinks.inputs = { };
    imports = [
      (
        { inputs, ... }:
        {
          imports = [ inputs.kit ];
        }
      )
      (
        { more, ... }:
        {
          imports = [ more ];
        }
      )
    ];
  };
  # a loop: `imports` reads `cfg`, and the module it imports gives `cfg`
  importsLoop = yen.eval {
    cfg = [ "root" ];
    yen.sinks.cfg.reduce = yen.reduce.flat;
    imports = [
      (
        { cfg, ... }:
        {
          imports = if b.length cfg == 1 then [ { cfg = [ "more" ]; } ] else [ ];
        }
      )
    ];
  };
  # an undeclared sink is `reduce.one`: two givers are the error one
  argsTwo = yen.eval {
    imports = [
      { cfg.a = "x"; }
      { cfg.a = "y"; }
      ({ cfg, ... }: { })
    ];
  };
  # `of` checks each module's value; a declared sink with no giver reduces to its empty value
  argsTyped = yen.eval {
    imports = [
      (
        { yen, ... }:
        {
          yen.sinks.port.of = yen.lib.is builtins.isInt;
          yen.sinks.extra.reduce = yen.lib.reduce.flat;
          yen.sinks.none.reduce = yen.lib.reduce.list;
          yen.sinks.bad.tpye = 1;
          port = 22;
          extra = [ "a" ];
        }
      )
      {
        port = "x";
        extra = [ "b" ];
      }
      (
        { extra, none, ... }:
        {
          imports = [ (fleet { addr = builtins.concatStringsSep "," (extra ++ none); }) ];
        }
      )
    ];
  };

  # stack safety: a chain 3000 deep, a fan-out of 3000
  deep =
    n:
    yen.eval (
      { yen, ... }:
      {
        yen.kinds.node.spawns.node =
          s:
          let
            i = b.fromJSON (b.substring 5 9 s.key);
          in
          if i < n then { "${toString (i + 1)}" = { }; } else { };
        yen.kinds.top.spawns.node = _: { "0" = { }; };
        yen.top.t = { };
      }
    );
  wide =
    n:
    yen.eval (
      { yen, ... }:
      {
        yen.kinds.root.spawns.leaf =
          _:
          b.listToAttrs (
            b.genList (i: {
              name = toString i;
              value = { };
            }) n
          );
        yen.kinds.leaf = { };
        yen.root.r = { };
      }
    );

  # tree driver, positive: a node reads its nearest cluster
  treeHit = yen.eval (
    { yen, ... }:
    {
      yen.kinds.top.spawns.cluster = _: yen.cluster;
      yen.kinds.cluster.spawns.node = _: { n1 = { }; };
      yen.kinds.node.sinks.seen = { };
      yen.top.t = { };
      yen.cluster.c1 = { };
      yen.aspects.see = {
        at = yen.kinds.node;
        cycle =
          { tree, ... }:
          let
            c.nearest = yen.kinds.cluster;
          in
          {
            tree = [ c ];
            seen = map (c: c.name) (tree.select c);
          };
      };
    }
  );
  # every tree request at one node: parent, a nearest with no answer, children, scopesOf, holds, one unknown
  treeAll = treeAllWith false;
  treeAllWith =
    bogus:
    yen.eval (
      { yen, ... }:
      {
        yen.kinds.top.spawns.cluster = _: yen.cluster;
        yen.kinds.cluster.spawns.node = _: { n1 = { }; };
        yen.kinds.node.spawns.pod = _: {
          p1 = { };
          p2 = { };
        };
        yen.kinds.node.sinks.seen = { };
        yen.kinds.pod = { };
        yen.top.t = { };
        yen.cluster.c1 = { };
        yen.aspects.see = {
          at = yen.kinds.node;
          cycle =
            { tree, ... }:
            let
              parent.parent = true;
              none.nearest = yen.kinds.pod; # no pod above a node: no answer
              kids.children = yen.kinds.pod;
              same.scopesOf = yen.cluster.c1;
              holds.holds = yen.kinds.node;
              all.instances = yen.kinds.cluster;
              bad = {
                category = "bad"; # a name: refused, a request is selected by itself
                holds = yen.kinds.pod;
              };
            in
            {
              tree = [
                parent
                none
                kids
                same
                holds
                all
              ]
              ++ b.filter (_: bogus) [ bad ];
              seen = {
                parent = map (s: s.id) (tree.select parent);
                none = tree.select none;
                kids = map (map (s: s.name)) (tree.select kids);
                same = map (map (s: s.id)) (tree.select same);
                holds = tree.select holds;
                all = map (map (c: c.name)) (tree.select all);
                bad = tree.select bad; # not asked: no answer
              };
            };
        };
      }
    );
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
  # what NixOS `config` (a fixpoint) expresses, in yen. Each line names the NixOS pattern.
  configLike = yen.eval (
    { yen, ... }:
    let
      one = yen.lib.reduce.one;
    in
    {
      yen.kinds.fleet = {
        spawns.host = _: yen.host;
        sinks.addrs.reduce = yen.lib.reduce.merge; # a value every host gives, read by every host
      };
      yen.kinds.host = {
        fields.addr = yen.lib.is builtins.isString;
        fields.fqdn = yen.lib.derive (yen.lib.is builtins.isString) (i: "${i.name}.lan"); # default = f config
        sinks = {
          ports.reduce = yen.lib.reduce.set; # a list option many modules define
          firewall.reduce = one;
          settings.reduce = yen.lib.reduce.merge; # an attrset option, deep-merged
          motd.reduce =
            es: # mkForce / mkDefault: the lowest priority number wins
            {
              value = (builtins.head (builtins.sort (a: c: a.value.prio < c.value.prio) es)).value.text;
              errors = [ ];
            };
          chain.reduce = one;
          mid.reduce = one;
          leaf.reduce = one;
          peers.reduce = one;
        };
      };
      yen.fleet.main = { };
      yen.host = {
        a.addr = "10.0.0.1";
        b.addr = "10.0.0.2";
      };
      yen.aspects = {
        # declared before what it reads: the order of definitions never matters
        chain = {
          at = yen.kinds.host;
          chain = { mid, ... }: mid * 10;
        };
        mid = {
          at = yen.kinds.host;
          mid = { leaf, ... }: leaf + 1;
        };
        leaf = {
          at = yen.kinds.host;
          leaf = 1;
        };
        web = {
          at = yen.host.a;
          ports = 80;
        };
        ssh = {
          at = yen.kinds.host;
          ports = 22;
        };
        tls = {
          at = yen.aspects.web; # mkIf config.services.web.enable
          ports = 443;
        };
        fw = {
          at = yen.kinds.host;
          firewall = { ports, ... }: builtins.sort builtins.lessThan ports; # an option read from another option
        };
        base = {
          at = yen.kinds.host;
          settings.a = 1;
          motd = {
            prio = 1000;
            text = "default";
          };
        };
        tuned = {
          at = yen.host.b;
          settings.b.c = 2;
          motd = {
            prio = 50;
            text = "forced";
          };
        };
        addrs = {
          at = yen.kinds.host;
          addrs =
            { host, ... }:
            {
              ${host.name} = host.addr;
            };
          peers = { host, addrs, ... }: removeAttrs addrs [ host.name ]; # nodes.<other>.config
        };
      };
    }
  );
  # rung 1 (vic/formally-verified.md): the law gates outputs and stage; grants by path segment, edges and values
  # a rule is a function of its variables; its literals are references (yen.facts, yen.relations)
  nofw = id: [
    "bad"
    "fw"
    id
  ];
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
  # every host has the firewall aspect
  fwRules =
    yen:
    { H }:
    {
      bad = H;
      pos = [ (yen.facts.kind yen.kinds.host H) ];
      neg = [ (yen.facts.has yen.aspects.firewall H) ];
    };
  codes = r: map (e: e.code) r.errors;
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
  rung1 = extra: {
    imports = [
      (
        { yen, ... }:
        {
          yen.kinds.top = {
            spawns.host = _: yen.host;
          };
          yen.kinds.host = {
            fields.port = yen.lib.opt (yen.lib.is b.isInt) 22;
            fields.bypass = yen.lib.maybe (yen.lib.is b.isBool);
            sinks.nixos.reduce = yen.lib.reduce.merge;
            sinks.fw = { };
          };
          yen.top.t = { };
          yen.host = {
            web = { };
            webhook = { };
            db = { };
          };
          yen.aspects.sshd = {
            at = yen.kinds.host;
            nixos =
              { host, ... }:
              {
                ports = [ host.port ];
              };
          };
          yen.aspects.fw = {
            at = yen.lib.all [
              yen.kinds.host
              (s: s.bypass == null)
            ];
            fw = "on";
          };
          yen.aspects.cyc.at = [ ];
          yen.relations = {
            p.arity = 0;
            q.arity = 0;
          };
          yen.invariants.cycle = [
            (_: {
              head = yen.relations.p;
              pos = [ (yen.facts.has yen.aspects.cyc "top:t") ];
              neg = [ yen.relations.q ];
            })
            (_: {
              head = yen.relations.q;
              pos = [ (yen.facts.has yen.aspects.cyc "top:t") ];
              neg = [ yen.relations.p ];
            })
            (_: {
              bad = [ ];
              pos = [ yen.relations.p ];
            })
          ];
          yen.flake.ok = true; # outputs exist only when the fleet is clean
        }
      )
    ]
    ++ extra;
  };
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
  # structure from presence (Den #525): a child exists only where an aspect holds at its parent
  presence = yen.eval (
    { yen, ... }:
    {
      yen.kinds.top.spawns.host = _: yen.host;
      yen.kinds.host.spawns.svc = p: if yen.lib.holds yen.aspects.server p then { web = { }; } else { };
      yen.kinds.svc = { };
      yen.top.t = { };
      yen.host = {
        a = { };
        b = { };
      };
      yen.aspects.server.at = yen.host.a;
    }
  );
  # a function element that reads a sink: two givers whose sink values differ are two elements, not one
  sinkArgs = yen.eval (
    { yen, ... }:
    {
      yen.kinds.fleet = {
        spawns.environment = _: yen.environment;
        sinks.seen = { };
      };
      yen.kinds.environment = {
        spawns.host =
          s:
          b.listToAttrs (
            map (n: {
              name = n;
              value = yen.host.${n};
            }) (b.filter (n: yen.host.${n}.environment.name == s.name) (b.attrNames yen.host))
          );
        sinks.tag.reduce = yen.lib.reduce.one;
      };
      yen.kinds.host.fields.environment = yen.kinds.environment;
      yen.fleet.main = { };
      yen.environment = {
        prod = { };
        staging = { };
      };
      yen.host = {
        a.environment = yen.environment.prod;
        b.environment = yen.environment.staging;
        c.environment = yen.environment.prod;
      };
      yen.aspects.envtag = {
        at = yen.kinds.environment;
        tag = { environment, ... }: environment.name;
      };
      yen.aspects.report = {
        at = yen.kinds.host;
        seen = { tag, ... }: tag;
      };
    }
  );

  # Den CI gaps closed: derived defaults, bad `at`, one key from many files, static once per receiver
  gaps = yen.eval gapsModule;
  gapsBadAt = yen.eval {
    imports = [
      gapsModule
      { yen.aspects.typo.at = "host"; }
    ];
  };
  gapsModule =
    { yen, ... }:
    {
      imports = [
        { yen.aspects.multi.nixos = { scope, ... }: [ "a-${scope.name}" ]; }
        { yen.aspects.multi.nixos = { scope, ... }: [ "b-${scope.name}" ]; }
      ];
      yen.kinds.fleet = {
        spawns.host = _: yen.host;
      };
      yen.kinds.host = {
        fields.vpn = yen.lib.derive (yen.lib.is b.isString) (self: "vpn-${self.name}");
        spawns.user = _: {
          u1 = { };
          u2 = { };
        };
        sinks.nixos = { };
      };
      yen.kinds.user = { };
      yen.fleet.main = { };
      yen.host = {
        h1 = { };
        h2.vpn = "custom";
      };
      yen.aspects.multi.at = yen.kinds.host;
      yen.aspects.shared = {
        at = [
          yen.kinds.host
          yen.kinds.user
        ];
        nixos = "marker";
      };
    };
  # aspect refs on cycles: three values (well-founded semantics)
  logic =
    cyclic:
    yen.eval (
      { yen, ... }:
      {
        yen.kinds.top.spawns.host = _: yen.host;
        yen.kinds.host.spawns.user = _: { u = { }; };
        yen.kinds.user = { };
        yen.top.t = { };
        yen.host.h = { };
        yen.aspects =
          let
            inherit (yen.lib)
              all
              not
              within
              below
              ;
          in
          {
            a.at = all [
              yen.kinds.host
              (not yen.aspects.b)
            ];
            b.at =
              if cyclic then
                all [
                  yen.kinds.host
                  (not yen.aspects.a)
                ]
              else
                yen.kinds.host;
            c.at = all [
              yen.kinds.host
              (not yen.aspects.a)
            ]; # reads an undefined: undefined too
            p.at = yen.aspects.q;
            q.at = yen.aspects.p; # a positive cycle: unfounded, false
            w.at = all [
              yen.kinds.user
              (within yen.aspects.b)
            ]; # within crosses scopes: no cycle
            v.at = all [
              yen.kinds.host
              (below yen.aspects.w)
            ];
          };
      }
    );
  diamond =
    k:
    yen.eval (
      { yen, ... }:
      {
        yen.kinds.top.spawns.host = _: yen.host;
        yen.kinds.host = { };
        yen.top.t = { };
        yen.host.h = { };
        yen.aspects = {
          x0.at = yen.kinds.host;
        }
        // b.listToAttrs (
          b.concatMap (
            i:
            let
              p = "x${toString (i - 1)}";
            in
            [
              {
                name = "l${toString i}";
                value.at = yen.aspects.${p};
              }
              {
                name = "r${toString i}";
                value.at = yen.aspects.${p};
              }
              {
                name = "x${toString i}";
                value.at = yen.lib.all [
                  yen.aspects."l${toString i}"
                  yen.aspects."r${toString i}"
                ];
              }
            ]
          ) (b.genList (i: i + 1) k)
        );
      }
    );

  G = yen.graphs;
  D = yen.datalog;
  K = yen.krn;
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
  choice = [
    {
      head = "a";
      neg = [ "b" ];
    }
    {
      head = "b";
      neg = [ "a" ];
    }
    {
      head = "c";
      pos = [ "a" ];
    }
    { head = "s"; }
    {
      head = "t";
      pos = [ "u" ];
    }
  ];

  # agent surface fixtures
  portsBase =
    { yen, ... }:
    {
      yen.kinds.top.spawns.host = _: yen.host;
      yen.kinds.host = {
        fields.port = {
          check = p: b.isInt p && p < 65536;
          name = "Port";
        };
        sinks.fw = { };
      };
      yen.top.t = { };
      yen.host = {
        a.port = 22;
        b.port = 80;
      };
      yen.aspects.firewall = {
        at = yen.host.a;
        fw = "on";
      };
      yen.invariants.fw = fwRules yen;
    };
  ports =
    extra:
    yen.eval (
      { yen, ... }:
      {
        imports = [ extra ];
        yen.kinds.top.spawns.host = _: yen.host;
        yen.kinds.host = {
          fields.port = {
            check = p: b.isInt p && p < 65536;
            name = "Port";
          };
          sinks.fw = { };
        };
        yen.top.t = { };
        yen.host = {
          a.port = 22;
          b.port = 80;
        };
        yen.aspects.firewall = {
          at = yen.host.a;
          fw = "on";
        };
        yen.invariants.fw = fwRules yen;
      }
    );
  rec1 = r: code: b.head (b.filter (e: e.code == code) r.errors);

in
{
  inherit
    yen
    b
    eq
    yes
    no
    msgs
    has
    fleet
    good
    noAddr
    feat
    featLazy
    hostOf
    ordered
    ids
    q5
    argsDown
    argsMissing
    argsSibling
    argsInImports
    importsRead
    importsLoop
    argsTwo
    argsTyped
    deep
    wide
    treeHit
    treeAll
    treeAllWith
    codesFix
    configLike
    nofw
    hasFw
    sshdWeb
    fwRules
    codes
    tagsWith
    tags
    rule2
    rung1
    r1stage
    T
    hostAt
    r1grant
    r1outside
    presence
    sinkArgs
    gaps
    gapsBadAt
    logic
    diamond
    G
    D
    K
    ring
    dag
    choice
    portsBase
    ports
    rec1
    ;
}
