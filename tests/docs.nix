# The docs battery oracles: tests.docs.<test> = { expr; expected; }. Run them: fastest --flake .#tests docs
self:
let
  inherit (self.tests._batteries)
    allKinds
    b
    bat
    cachesRun
    codes
    docR
    eq
    evalR
    ffR
    gatesV
    gh
    ghWf
    grouped
    has
    jsonR
    kindsV
    labelOf
    linkRun
    mkshellR
    mm
    mmText
    nestR
    nid
    no
    numtideR
    routeLabelOf
    routesV
    routingV
    scopesV
    sinksV
    specRun
    usersR
    vocabRun
    yes
    ;
in
{
  editors-vscode =
    eq
      ((bat.editors.vscode { from.__sink = "v"; } {
        sinks.v = [
          {
            extensions = [ "nix" ];
            settings.a = 1;
          }
          {
            extensions = [
              "nix"
              "go"
            ];
            settings.b = 2;
          }
        ];
      }).programs.vscode.profiles.default
      )
      ({
        extensions = [
          "nix"
          "go"
        ];
        userSettings = {
          a = 1;
          b = 2;
        };
      });
  editors-zed = eq ((bat.editors.zed { from.__sink = "z"; } {
    sinks.z = [ { extensions = [ "nix" ]; } ];
  }).programs.zed-editor.extensions
  ) ([ "nix" ]);
  ai-extensions =
    eq
      (bat.ai.extensions
        {
          from.__sink = "x";
          types = [ "mcp" ];
          build = map (e: e.name);
        }
        {
          sinks.x = [
            {
              type = "mcp";
              name = "gh";
            }
            {
              type = "skill";
              name = "s";
            }
            [
              {
                type = "mcp";
                name = "list"; # an element that is a list of records
              }
            ]
          ];
        }
      )
      ([
        "gh"
        "list"
      ]);
  ai-skills = eq (map (s: s.name) (bat.ai.skills ./fixtures/skills)) ([ "review" ]);
  docs-table = eq (bat.docs.table
    [ "A" "B" ]
    [
      [
        "1"
        "2"
      ]
    ]
  ) ("| A | B |\n|---|---|\n| 1 | 2 |");
  docs-kinds =
    eq
      (bat.docs.kinds
        {
          box = {
            fields.x = 1;
            sinks.s = { };
          };
        }
        {
          scopes = [
            { kind = "box"; }
            { kind = "box"; }
          ];
        }
      )
      (
        "| Kind | Fields | Spawns | Sinks | Scopes |\n|---|---|---|---|---|\n| `box` | `x` |  | `s` | 2 |"
      );
  docs-templates = {
    t1 = yes (
      b.attrNames (
        bat.docs.templates {
          root = ../docs/examples;
          description = _: "";
        }
      ) != [ ]
    );
    t2 = no (
      (bat.docs.templates {
        root = ../docs/examples;
        description = _: "";
      }) ? about
    ); # docs/examples/about has no flake.nix
  };
  files-comment = {
    t1 = eq (bat.files.comment "README.md" "x") ("<!-- x -->\n");
    t2 = eq (bat.files.comment "a/ci.yml" "x") ("# x\n");
    t3 = eq (bat.files.comment "main.rs" "x") ("// x\n");
    t4 = eq (bat.files.comment "ci.json" "x") ("");
  };
  files-toml = eq (bat.files.toml { } {
    p.name = "a b";
    p."x.y" = [
      1
      true
    ];
    t.k.inline = {
      a = 1;
    };
  }) ("[p]\nname = \"a b\"\n\"x.y\" = [1, true]\n\n[t.k]\ninline = { a = 1 }\n");
  secretspec-toml = eq ((specRun { }).flake.sys.a) ([
    {
      files.file."secretspec.toml".text =
        "[profiles.default]\nDB_URL = { description = \"db\" }\n\n[profiles.dev]\nDB_URL = { default = \"sqlite://x\" }\ndefaults = { inherit = false }\n\n[project]\nname = \"app\"\n";
    }
  ]);
  secretspec-twice = eq (codes (
    specRun (
      { yen, ... }:
      {
        yen.aspects.s3 = {
          at = yen.person.p; # another scope than s1: two owners
          secrets.name = "DB_URL";
        };
      }
    )
  )) ([ "claim" ]);
  cachix-caches = eq (cachesRun.flake.sys.a) ([
    {
      nix.settings = {
        substituters = [
          "https://vix.cachix.org"
          "https://cache.example"
        ];
        trusted-public-keys = [
          "vix.cachix.org-1:K"
          "own-1:K"
        ];
      };
    }
  ]);
  cachix-flake-config =
    eq
      ((bat.cachix.flake-config { from.__sink = "c"; } {
        sinks.c = [
          {
            name = "vix";
            publicKey = "k";
          }
        ];
      }).nixConfig
      )
      ({
        extra-substituters = [ "https://vix.cachix.org" ];
        extra-trusted-public-keys = [ "k" ];
      });
  cachix-action = eq ((bat.cachix.action { name = "vix"; }).uses) ("cachix/cachix-action@v17");
  files-json = eq (jsonR.flake.sys.a) ([ { files.file."ci.json".text = "[\"a\",\"b\"]\n"; } ]);
  flake-file-write = eq (ffR.flake.sys.a) ([
    {
      packages.sx.write-flake = [
        "ffm"
        {
          flake-file.inputs = {
            x.url = "u1";
            y.url = "u2";
          };
        }
        "extra"
      ];
      checks.sx.flake-file = "sx";
    }
  ]);
  devshell-numtide = eq (numtideR.flake.sys.a) ([
    {
      devShells.sx.default = {
        name = "n";
        packages = [ "sx" ];
        commands = [
          { name = "one"; }
          {
            name = "two";
            packages = [ "pk" ];
            shellHook = "h;";
          }
        ];
      };
    }
  ]);
  devshell-mkshell = eq (mkshellR.flake.sys.a) ([
    {
      devShells.a.default = {
        packages = [ "pk" ];
        shellHook = "h;";
        on = "a";
      };
    }
  ]);
  docs-links = eq ((linkRun "datalog oracles").flake.got) ({ dl = "[`datalog`](datalog.nix#L1)"; });
  docs-links-gone = eq (codes (linkRun "zz-none-yen")) ([ "link-gone" ]);
  docs-vocabulary = eq ((vocabRun allKinds).errors) ([ ]);
  docs-vocabulary-drift =
    eq (b.sort b.lessThan (codes (vocabRun (b.removeAttrs allKinds [ "box" ] // { ghost = "x"; }))))
      ([
        "doc-missing"
        "doc-stale"
      ]);
  mermaid-kinds = {
    t1 = yes (
      b.elem {
        from = "k:box";
        to = "k:person";
      } kindsV.edges
    );
    t2 = yes (
      b.elem {
        from = "k:person";
        to = "k:box";
        label = "home";
        live = false;
      } kindsV.edges
    );
  };
  mermaid-gates = {
    t1 = yes (
      b.elem {
        from = "a:g1";
        to = "a:g2";
        label = "";
        live = true;
      } gatesV.edges
    );
    t2 = yes (
      b.elem {
        from = "a:g3";
        to = "a:g2";
        label = "not";
        live = false;
      } gatesV.edges
    );
    t3 = yes (
      b.elem {
        from = "f:g3";
        to = "a:g3";
        label = "";
        live = true;
      } gatesV.edges
    );
  };
  mermaid-routing = {
    t1 = yes (
      b.elem {
        from = "s:sys";
        to = "k:box";
        label = "1";
      } routingV.edges
    );
    t2 = yes (
      b.elem {
        from = "k:box";
        to = "s:sys";
        label = "1";
      } routingV.edges
    );
  };
  mermaid-sinks = yes (
    b.elem {
      from = "sink:sys";
      to = "flake";
      label = "a";
    } sinksV.edges
  );
  mermaid-nested = {
    clean = eq nestR.errors [ ];
    scopes = eq (labelOf "x:a/y:b") "x.kinds.y b";
    routes = eq (routeLabelOf "x:a/y:b") "x.kinds.y b";
    flowchart-scopes = yes (has "[\"x.kinds.y b\"]" (mm.flowchart { } (mm.scopes { } nestR.graph)));
    flowchart-routes = yes (has "[\"x.kinds.y b\"]" (mm.flowchart { } (mm.routes nestR.graph)));
    # a string kind with a shape keeps it; the nested node beside it stays a box
    flowchart-shapes =
      let
        text = mm.flowchart { shapes.x = mm.shapes.round; } (mm.scopes { } nestR.graph);
      in
      yes (has "(\"x a\")" text && has "[\"x.kinds.y b\"]" text);
    routing = yes (
      b.elem {
        from = "k:x.kinds.y";
        to = "s:fw";
        label = "1";
      } (mm.routing nestR.graph).edges
    );
    gates = yes (
      b.elem {
        from = "r:kind x.kinds.y";
        to = "a:n1";
        label = "";
        live = true;
      } nestR.flake.views.gates.edges
    );
    kinds = yes (
      b.elem {
        from = "k:z";
        to = "k:x.kinds.y";
        label = "r";
        live = false;
      } nestR.flake.views.kinds.edges
    );
  };
  mermaid-scopes-options = {
    t1 = no ((b.any (n: n.id == "top:t") grouped.nodes));
    t2 = yes (
      b.elem {
        id = "top:t/box:a/person:p";
        kind = "person";
        label = "p";
        group = "top:t/box:a";
      } grouped.nodes
    );
    t3 = eq (grouped.edges) ([ ]);
  };
  github-yaml = eq (gh.yaml {
    k = [
      "v"
      { x = { }; }
    ];
    s = "a\nb\n";
    "q:" = true;
  }) ("\"k\":\n  - \"v\"\n  -\n    \"x\": {}\n\"q:\": true\n\"s\": |\n  a\n  b\n");
  github-workflow = eq (ghWf.flake.sys.a) ([
    {
      files.file."ci.yml".text =
        "# a b\n\"jobs\":\n  \"a\":\n    \"steps\":\n      -\n        \"run\": |\n          one\n          two\n  \"b\":\n    \"runs-on\": \"x\"\n\"name\": \"t\"\n";
    }
  ]);
  files-document = eq (docR.flake.sys.a) ([ { files.file."README.md".text = "a\nb"; } ]);
  mermaid-flowchart = eq (mmText) (
    b.concatStringsSep "\n" [
      "flowchart LR"
      "  subgraph ${nid "g"} [\"env\"]"
      "    ${nid "a"}[\"say 'hi'\"]"
      "  end"
      "  ${nid "d"}[(\"store\")]"
      "  ${nid "a"} -.->|\"writes\"| ${nid "d"}"
    ]
  );
  mermaid-scopes = {
    t1 = eq (b.length scopesV.nodes) (b.length usersR.graph.scopes);
    t2 = yes (
      b.elem {
        from = "top:t";
        to = "top:t/box:a";
      } scopesV.edges
    );
  };
  mermaid-routes = {
    t1 = yes (b.all (e: e.from != e.to) routesV.edges);
    t2 = yes (
      b.elem {
        from = "top:t/box:a/person:p";
        to = "top:t/box:a";
        label = "sys";
      } routesV.edges
    );
  };
  eval-modules = eq (evalR.flake.sys.a) ([
    {
      modules = [
        "fixed"
        "from-a"
      ];
      specialArgs.x = 1;
    }
  ]);
}
