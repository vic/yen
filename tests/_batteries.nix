# The fixtures and helpers the battery suites share: each suite inherits what it reads from `self.tests._batteries`.
self:
let
  yen = self.api;
  b = builtins;
  # a fastest test: { expr; expected; }
  eq = expr: expected: { inherit expr expected; };
  yes = x: eq x true;
  no = x: eq x false;
  nixos = yen.batteries.nixos;
  bat = yen.batteries;
  # every .nix file under a directory
  nixUnder =
    d:
    b.concatLists (
      b.attrValues (
        b.mapAttrs (
          n: t:
          if t == "directory" then
            nixUnder (d + "/${n}")
          else if b.match ".*\\.nix" n != null then
            [ (d + "/${n}") ]
          else
            [ ]
        ) (b.readDir d)
      )
    );
  # the module files of each directory under d that has a `modules/`
  modulesIn =
    d:
    b.concatMap (
      n: if b.pathExists (d + "/${n}/modules") then nixUnder (d + "/${n}/modules") else [ ]
    ) (b.attrNames (b.readDir d));
  letsIn =
    f:
    b.length (b.filter (l: b.isString l && b.match "[ ]*let" l != null) (b.split "\n" (b.readFile f)));
  # the words of this fleet: no battery knows them. Every box gives its `sys` list as output.
  fleet =
    { yen, ... }:
    {
      yen.kinds.top = {
        spawns.box = _: yen.box;
        sinks.out.reduce = yen.lib.reduce.merge;
      };
      yen.kinds.box = {
        spawns.person = s: if s.name == "a" then { inherit (yen.person) p; } else { };
        sinks.sys.out =
          { scope, sinks, ... }:
          {
            sys.${scope.name} = sinks.${yen.kinds.box.sinks.sys.__sink};
          };
      };
      yen.kinds.person = { };
      yen.top.t = { };
      yen.box = {
        a = { };
        c = { };
      };
      yen.person.p = { };
      yen.flake = { out, ... }: out;
    };
  run = ms: yen.eval { imports = [ fleet ] ++ ms; };

  # engine: a sink carries its name; the fixed arg `sinks` reads the nearest receiver of each sink
  sinkRefs = run [
    (
      { yen, ... }:
      {
        yen.kinds.box.sinks.names = { };
        yen.aspects.n = {
          at = yen.box.a;
          names = "steam";
        };
        yen.aspects.read = {
          at = yen.person.p; # a person has no `names` sink: `sinks.names` is its box's
          sys =
            { sinks, ... }:
            {
              seen = sinks.names;
              hasSys = sinks ? sys;
              hasOut = sinks ? out;
              name = yen.kinds.box.sinks.names.__sink;
            };
        };
      }
    )
  ];
  reserved = run [ { yen.kinds.box.sinks.sinks = { }; } ];
  # a field with the name of a scope key would be shadowed by it: an error, never a silent wrong value
  reservedField = run [
    (
      { yen, ... }:
      {
        yen.kinds.box.fields.key = yen.lib.opt (yen.lib.is builtins.isString) "k";
      }
    )
  ];
  # the engine rule: a functor with `__functionArgs` is a function
  functorR = run [
    (
      { yen, ... }:
      {
        yen.aspects.f = {
          at = yen.box.c;
          sys = {
            __functor = _: a: "at ${a.scope.name}";
            __functionArgs.scope = false;
          };
        };
      }
    )
  ];
  # value batteries: you write the aspect and its keys
  usersR = run [
    (
      { yen, ... }:
      {
        yen.aspects.hn = {
          at = yen.box.a;
          sys = nixos.hostname;
        };
        yen.aspects.account = {
          at = yen.kinds.person; # a person has no `sys` sink: its account lands in its box's
          sys = nixos.define-user;
        };
        yen.aspects.admin = {
          at = yen.person.p;
          sys = nixos.primary-user { };
        };
      }
    )
  ];
  # a battery that reads a sink takes it as a ref
  unfreeR = run [
    (
      { yen, ... }:
      {
        yen.kinds.box.sinks.unfree.sys = nixos.unfree { from = yen.kinds.box.sinks.unfree; };
        yen.aspects.u = {
          at = yen.box.a;
          unfree = [ "steam" ];
        };
        yen.aspects.v = {
          at = yen.person.p;
          unfree = [ "vscode" ];
        };
      }
    )
  ];
  pred =
    ((b.head unfreeR.flake.sys.a) {
      lib = {
        inherit (b) elem;
        getName = p: p.pname;
        flatten = b.concatLists;
      };
    }).nixpkgs.config.allowUnfreePredicate;

  # mesh: every box reads the keys of the others, never its own nor its people's
  meshR = run [
    (
      { yen, ... }:
      {
        yen.kinds.top.sinks.keys.reduce = yen.lib.reduce.elements;
        yen.aspects.key = {
          at = [
            yen.kinds.box
            yen.kinds.person
          ];
          keys = { scope, ... }: scope.name;
        };
        yen.aspects.peers = {
          at = yen.kinds.box;
          sys = bat.mesh {
            from = yen.kinds.top.sinks.keys;
            build = ks: { peers = b.sort b.lessThan ks; };
          };
        };
      }
    )
  ];
  # a top sink read back as a flake output, with a reduce under test
  topRun =
    reduce: gives:
    run [
      (
        { yen, ... }:
        {
          yen.kinds.top.sinks.got = {
            inherit reduce;
            out =
              { sinks, ... }:
              {
                got = sinks.got;
              };
          };
          yen.aspects = b.mapAttrs (n: g: {
            inherit (g) at;
            got = g.v;
          }) (gives yen);
        }
      )
    ];
  codes = r: map (e: e.code or null) r.errors;
  claimOk = topRun (bat.claim { key = v: v.addr; }) (yen: {
    a = {
      at = yen.box.a;
      v.addr = "10.0.0.1";
    };
    p = {
      at = yen.person.p;
      v.addr = "10.0.0.2";
    };
  });
  claimBad = topRun (bat.claim { key = v: v.addr; }) (yen: {
    a = {
      at = yen.box.a;
      v.addr = "10.0.0.1";
    };
    c = {
      at = yen.box.c;
      v.addr = "10.0.0.1";
    };
  });
  claimRank =
    topRun
      (bat.claim {
        key = v: v.dev;
        rank = v: v.prio;
      })
      (yen: {
        a = {
          at = yen.box.a;
          v = {
            dev = "gpu0";
            prio = 1;
          };
        };
        c = {
          at = yen.box.c;
          v = {
            dev = "gpu0";
            prio = 9;
          };
        };
      });
  sections =
    vs: yen:
    b.mapAttrs (n: v: {
      at = yen.box.a;
      inherit v;
    }) vs;
  orderedOk = topRun bat.ordered (sections {
    s1 = {
      name = "head";
      value = "H";
    };
    s2 = {
      name = "body";
      value = "B";
      after = [ "head" ];
    };
    s3 = {
      name = "foot";
      value = "F";
      after = [ "body" ];
    };
    s4 = {
      name = "toc";
      value = "T";
      after = [ "head" ];
      before = [ "body" ];
    };
  });
  orderedCycle = topRun bat.ordered (sections {
    x = {
      name = "x";
      value = 0;
      after = [ "y" ];
    };
    y = {
      name = "y";
      value = 0;
      after = [ "x" ];
    };
  });
  orderedTypo = topRun bat.ordered (sections {
    x = {
      name = "x";
      value = 0;
      after = [ "hed" ];
    };
  });

  # eval-modules: fixed modules first, then the sink's, given to lib.evalModules with specialArgs (a stub lib records them)
  evalR = run [
    (
      { yen, ... }:
      {
        yen.kinds.box.sinks.mods.sys = bat.eval-modules {
          from = yen.kinds.box.sinks.mods;
          lib.evalModules = a: { config = a; };
          modules = [ "fixed" ];
          specialArgs.x = 1;
        };
        yen.aspects.m = {
          at = yen.box.a;
          mods = "from-a";
        };
      }
    )
  ];

  mm = bat.mermaid;
  # one view: a group around a node, a shaped node, a dashed labelled edge, a quote in a label
  mmText =
    mm.flowchart
      {
        shapes = with mm.shapes; {
          db = cylinder;
        };
      }
      {
        nodes = [
          {
            id = "g";
            label = "env";
          }
          {
            id = "a";
            label = "say \"hi\"";
            group = "g";
          }
          {
            id = "d";
            label = "store";
            kind = "db";
          }
        ];
        edges = [
          {
            from = "a";
            to = "d";
            label = "writes";
            live = false;
          }
        ];
      };
  nid = id: "n${b.substring 0 10 (b.hashString "md5" id)}";
  scopesV = mm.scopes { } usersR.graph;
  routesV = mm.routes usersR.graph;

  # files.document: the texts of an ordered sink, joined, as one repo file
  docR = run [
    (
      { yen, ... }:
      {
        yen.kinds.box.sinks.doc.reduce = bat.ordered;
        yen.aspects.doc = {
          at = yen.box.a;
          sys = bat.files.document {
            from = yen.kinds.box.sinks.doc;
            path = "README.md";
          };
        };
        yen.aspects.d1 = {
          at = yen.box.a;
          doc = {
            name = "end";
            after = [ "top" ];
            value = "b";
          };
        };
        yen.aspects.d2 = {
          at = yen.person.p;
          doc = {
            name = "top";
            value = "a";
          };
        };
      }
    )
  ];

  gh = bat.github;
  ghWf = run [
    (
      { yen, ... }:
      {
        yen.kinds.box.sinks.jobs = {
          reduce = yen.lib.reduce.merge;
          sys = gh.workflow {
            from = yen.kinds.box.sinks.jobs;
            path = "ci.yml";
            header = js: "# ${toString js}\n";
            doc.name = "t";
          };
        };
        yen.aspects.j1 = {
          at = yen.box.a;
          jobs.b.runs-on = "x";
        };
        yen.aspects.j2 = {
          at = yen.person.p;
          jobs.a.steps = [ { run = "one\ntwo\n"; } ];
        };
      }
    )
  ];

  # views: a ref field, two gates (one under a `not`), a fact test
  viewR = run [
    (
      { yen, ... }:
      {
        yen.kinds.person.fields.home = yen.lib.maybe yen.kinds.box; # a ref through maybe
        yen.aspects.g1.at = yen.kinds.box;
        yen.aspects.g2 = {
          at = yen.lib.all [
            yen.aspects.g1
            (yen.lib.not yen.aspects.g3)
          ];
          sys = "two";
        };
        yen.aspects.g3.at = s: s.name == "c";
        yen.aspects.g4.at = yen.aspects.g2; # makes g2 a gate: its own `at` is drawn
        # the declarations are the whole fleet: a reader of them asks the `graph` request
        yen.aspects.views = {
          at = yen.top.t;
          cycle =
            { tree, ... }:
            let
              whole.graph = true;
              y = tree.select whole;
            in
            {
              tree = [ whole ];
              out = [
                {
                  views = {
                    kinds = mm.kinds y.kinds;
                    gates = mm.gates y.aspects;
                  };
                }
              ];
            };
        };
      }
    )
  ];
  inherit (viewR.flake.views) kinds gates;
  kindsV = kinds;
  gatesV = gates;
  routingV = mm.routing viewR.graph;
  sinksV = mm.sinks {
    inherit (viewR) schema graph;
  };
  grouped = mm.scopes {
    keep = s: s.kind != "top";
    label = s: s.name;
    group = s: if s.kind == "person" then "top:t/box:a" else null;
  } viewR.graph;
  # c47: every view names a nested kind by its kind path (a ref field, a gate, a scope)
  nestR = run [
    (
      { yen, ... }:
      {
        yen.kinds.x.kinds.y.sinks.fw.reduce = yen.lib.reduce.list;
        yen.kinds.z.fields.r = yen.lib.maybe yen.kinds.x.kinds.y;
        yen.x.a.y.b = { };
        yen.aspects.n1 = {
          at = yen.kinds.x.kinds.y;
          fw = "on";
        };
        yen.aspects.n2.at = yen.aspects.n1;
        yen.aspects.views = {
          at = yen.top.t;
          cycle =
            { tree, ... }:
            let
              whole.graph = true;
              y = tree.select whole;
            in
            {
              tree = [ whole ];
              out = [
                {
                  views = {
                    kinds = mm.kinds y.kinds;
                    gates = mm.gates y.aspects;
                  };
                }
              ];
            };
        };
      }
    )
  ];
  has = needle: text: b.replaceStrings [ needle ] [ "" ] text != text;
  labelOf = id: (b.head (b.filter (n: n.id == id) (mm.scopes { } nestR.graph).nodes)).label;
  routeLabelOf = id: (b.head (b.filter (n: n.id == id) (mm.routes nestR.graph).nodes)).label;

  linkRun =
    needle:
    topRun (bat.docs.links { root = ./.; }) (yen: {
      l = {
        at = yen.box.a;
        v = {
          name = "dl";
          file = "datalog.nix";
          inherit needle;
          text = "datalog";
        };
      };
    });
  vocabRun =
    lines:
    run [
      (
        { yen, ... }:
        {
          yen.aspects.vocab = {
            at = yen.top.t;
            errors = bat.docs.vocabulary {
              what = "kinds";
              names = builtins.attrNames yen.kinds;
              inherit lines;
            };
          };
        }
      )
    ];
  allKinds = {
    top = "root";
    box = "a box";
    person = "a person";
  };

  # devshells with stub builders: they return what they get
  shellRun =
    wrap: sys:
    run [
      (
        { yen, ... }:
        {
          yen.kinds.box.sinks.cmds.sys = sys yen;
          yen.aspects.c1 = {
            at = yen.box.a;
            cmds = wrap { name = "one"; };
          };
          yen.aspects.c2 = {
            at = yen.person.p;
            cmds = wrap {
              name = "two";
              packages = [ "pk" ];
              shellHook = "h;";
            };
          };
        }
      )
    ];
  numtideR = shellRun (c: [ c ]) (
    yen:
    bat.devshell.numtide {
      from = yen.kinds.box.sinks.cmds;
      devshell.legacyPackages.sx.mkShell = a: a;
      systems = [ "sx" ];
      pkgsOf = s: { tool = s; };
      name = "n";
      packages = pkgs: [ pkgs.tool ];
    }
  );
  mkshellR = shellRun (c: c) (
    yen:
    bat.devshell.mkshell {
      from = yen.kinds.box.sinks.cmds;
      pkgsOf = s: { mkShell = a: a // { on = s.name; }; };
    }
  );

  # flake-file.write with a stub lib: the merged sink is one module after flake-file's own
  ffR = run [
    (
      { yen, ... }:
      {
        yen.kinds.box.sinks.ff = {
          reduce = yen.lib.reduce.merge;
          sys = bat.flake-file.write {
            from = yen.kinds.box.sinks.ff;
            lib.evalModules = a: {
              config.flake-file = {
                apps.write-flake = p: a.modules;
                check-flake-file = p: p.stdenv.hostPlatform.system;
              };
            };
            inputs.flake-file.flakeModules.flake = "ffm";
            pkgs.stdenv.hostPlatform.system = "sx";
            modules = [ "extra" ];
          };
        };
        yen.aspects.f1 = {
          at = yen.box.a;
          ff.inputs.x.url = "u1";
        };
        yen.aspects.f2 = {
          at = yen.person.p;
          ff.inputs.y.url = "u2";
        };
      }
    )
  ];

  jsonR = run [
    (
      { yen, ... }:
      {
        yen.kinds.box.sinks.jobs = {
          reduce = yen.lib.reduce.merge;
          sys = bat.files.json {
            from = yen.kinds.box.sinks.jobs;
            path = "ci.json";
            value = builtins.attrNames;
          };
        };
        yen.aspects.j1 = {
          at = yen.box.a;
          jobs.b = 1;
        };
        yen.aspects.j2 = {
          at = yen.person.p;
          jobs.a = 2;
        };
      }
    )
  ];

  # kits batteries as plain functions of data: refs are `{ kind; name; }`, kHolds runs a function predicate
  kt = bat.kits;
  kHolds = p: m: b.isFunction p && p m;
  kRef = kind: name: { inherit kind name; };
  kIs = h: m: m.name == h.name;
  kDb = kRef "kit" "db" // {
    roles.server.interface.port = {
      type = {
        check = b.isInt;
        description = "int";
      };
      default = 5432;
    };
    roles.client = { };
    constraints = {
      roles.server = {
        min = 1;
        max = 1;
      };
      maxAssemblies = 1;
    };
    exports = [ "endpoint" ];
  };
  hA = kRef "host" "a" // {
    db = true;
  };
  hC = kRef "host" "c" // {
    db = false;
  };
  kMachines = [
    hA
    hC
  ];
  aMain = kRef "assembly" "main" // {
    kit = kDb;
    roles.server = {
      at = m: m.db;
      settings = m: { port = 1; };
    };
    roles.client.at = kIs hC;
  };
  kContract =
    assemblies:
    kt.contract {
      inherit assemblies;
      holds = kHolds;
      machines = kMachines;
    };

  # vars batteries as plain functions
  gen =
    xs:
    bat.vars.generators { machineOf = s: s; } (
      map (x: {
        from.name = x.m;
        value = x.v;
      }) xs
    );
  gens = gen [
    {
      m = "a";
      v = {
        name = "ssh";
        files.key.secret = true;
        files."key.pub".secret = false;
      };
    }
    {
      m = "c";
      v = {
        name = "ssh";
        files.key.secret = true;
      };
    }
    {
      m = "a";
      v = {
        name = "wifi";
        share = true;
        files.pw = { };
        files.ca = {
          deploy = false;
        };
      };
    }
    {
      m = "c";
      v = {
        name = "wifi";
        share = true;
        files.pw = { };
      };
    }
    {
      m = "a";
      v = {
        name = "borg";
        dependencies = [ "ssh" ];
        files.pass.neededFor = "users";
      };
    }
    {
      m = "a";
      v = null;
    }
  ];
  badDeps = gen [
    {
      m = "c";
      v = {
        name = "borg";
        dependencies = [ "nope" ];
      };
    }
  ];
  plan =
    (bat.vars.vars-plan {
      from.__sink = "g";
      machines = [ "a" ];
      recipientsOf = m: [ "r-${m}" ];
    } { sinks.g = gens.value; }).varsPlan.a;
  secretReads =
    bat.vars.secret-reads
      {
        from.__sink = "g";
        reads.__sink = "r";
      }
      {
        sinks = {
          g = gens.value;
          r = [
            {
              value = {
                machine = "a";
                generator = "ssh";
                file = "key";
              };
            }
            {
              value = {
                machine = "a";
                generator = "ssh";
                file = "key.pub";
              };
            }
          ];
        };
      };
  pub = bat.vars.public-value { root = ./fixtures/vars; };
  kh = bat.vars.known-hosts {
    from.__sink = "x";
    rootOf = _: ./fixtures/vars;
    keep = _: e: e.role == "server";
    entry = e: {
      host = e.machine.name;
      machine = e.machine.name;
      inherit (e.value.hostKey) generator file;
    };
  };
  khArgs = {
    scope = { };
    sinks.x =
      map
        (m: {
          machine.name = m;
          role = "server";
          value.hostKey = {
            generator = "openssh";
            file = "key.pub";
          };
        })
        [
          "lb"
          "nope"
        ]
      ++ [
        {
          machine.name = "c";
          role = "client";
          value.hostKey = {
            generator = "openssh";
            file = "key.pub";
          };
        }
      ];
  };

  # secretspec through a claim sink: one secret per (profile, name)
  specRun =
    extra:
    run [
      (
        { yen, ... }:
        {
          yen.kinds.box.sinks.secrets = {
            reduce = bat.claim { key = s: "${s.profile or "default"}/${s.name}"; };
            sys = bat.secretspec.toml {
              from = yen.kinds.box.sinks.secrets;
              project.name = "app";
              profiles.dev.defaults."inherit" = false;
            };
          };
          yen.aspects.s1 = {
            at = yen.box.a;
            secrets = {
              name = "DB_URL";
              description = "db";
            };
          };
          yen.aspects.s2 = {
            at = yen.person.p;
            secrets = {
              name = "DB_URL";
              profile = "dev";
              default = "sqlite://x";
            };
          };
        }
      )
      extra
    ];
  cachesRun = run [
    (
      { yen, ... }:
      {
        yen.kinds.box.sinks.caches = {
          sys = bat.cachix.caches { from = yen.kinds.box.sinks.caches; };
        };
        yen.aspects.c1 = {
          at = yen.box.a;
          caches = {
            name = "vix";
            publicKey = "vix.cachix.org-1:K";
          };
        };
        yen.aspects.c2 = {
          at = yen.person.p;
          caches = {
            name = "own";
            url = "https://cache.example";
            publicKey = "own-1:K";
          };
        };
        yen.aspects.c3 = {
          at = yen.box.a;
          caches = {
            name = "vix";
            publicKey = "vix.cachix.org-1:K";
          };
        };
      }
    )
  ];

  # NixOS batteries called directly: yen args, then NixOS module args
  sc = name: {
    inherit name;
    id = "f/host:${name}";
  };
  ent = name: v: {
    from.id = "f/host:${name}";
    value = v;
  };
  peers = [
    (ent "a" {
      name = "a";
      addr = "10.0.0.1";
      key = "ka";
    })
    (ent "c" {
      name = "c";
      addr = "10.0.0.2";
    })
  ];
  builders = [
    (ent "a" {
      hostName = "a";
      system = "x86_64-linux";
    })
    (ent "c" {
      hostName = "c";
      system = "aarch64-linux";
    })
    (ent "d" {
      hostName = "d";
      system = "x86_64-linux";
    })
  ];

in
{
  inherit
    allKinds
    aMain
    b
    badDeps
    bat
    builders
    cachesRun
    claimBad
    claimOk
    claimRank
    codes
    docR
    eq
    evalR
    ffR
    functorR
    gatesV
    gen
    gens
    gh
    ghWf
    grouped
    hA
    has
    hC
    jsonR
    kContract
    kDb
    kh
    khArgs
    kHolds
    kindsV
    kIs
    kRef
    kt
    labelOf
    letsIn
    linkRun
    meshR
    mkshellR
    mm
    mmText
    modulesIn
    nestR
    nid
    nixos
    nixUnder
    no
    numtideR
    orderedCycle
    orderedOk
    orderedTypo
    peers
    plan
    pred
    pub
    reserved
    reservedField
    routeLabelOf
    routesV
    routingV
    sc
    scopesV
    secretReads
    sinkRefs
    sinksV
    specRun
    unfreeR
    usersR
    viewR
    vocabRun
    yes
    ;
}
