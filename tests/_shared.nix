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

  # rung 1 (vic/formally-verified.md): the law gates outputs and stage; grants by path segment, edges and values
  # a rule is a function of its variables; its literals are references (yen.facts, yen.relations)
  nofw = id: [
    "bad"
    "fw"
    id
  ];
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

  # Den CI gaps closed: derived defaults, bad `at`, one key from many files, static once per receiver
  gaps = yen.eval gapsModule;
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

  D = yen.datalog;
  K = yen.uKanren;
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
    hostOf
    ordered
    ids
    deep
    wide
    nofw
    fwRules
    codes
    rung1
    gaps
    gapsModule
    logic
    diamond
    D
    K
    choice
    portsBase
    ports
    ;
}
