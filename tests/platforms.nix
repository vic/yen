# The platforms battery oracles: tests.platforms.<test> = { expr; expected; }. Run them: fastest --flake .#tests platforms
self:
let
  inherit (self.tests._batteries)
    b
    bat
    builders
    eq
    nixos
    no
    peers
    pred
    sc
    unfreeR
    yes
    ;
in
{
  deploy-colmena =
    eq
      (bat.deploy.colmena {
        from.__sink = "c";
        makeHive = h: h;
        meta.nixpkgs = "p";
      } { sinks.c.lb = "m"; })
      ({
        colmenaHive = {
          meta.nixpkgs = "p";
          lb = "m";
        };
      });
  deploy-rs =
    eq
      ((bat.deploy.deploy-rs {
        configurations.lb = "C";
        hostname = n: _: "${n}.lan";
        activate = _: c: "act-${c}";
      }).deploy.nodes.lb
      )
      ({
        hostname = "lb.lan";
        profiles.system = {
          user = "root";
          sshUser = "root";
          path = "act-C";
        };
      });
  secrets-sops-config =
    eq
      (bat.secrets.sops-config { from.__sink = "r"; } {
        sinks.r = [
          {
            path_regex = "a";
            age = "k";
          }
        ];
      })
      ({
        files.file.".sops.yaml".text =
          "\"creation_rules\":\n  -\n    \"age\": \"k\"\n    \"path_regex\": \"a\"\n";
      });
  terranix-configuration =
    eq
      ((bat.terranix.configuration
        {
          from.__sink = "t";
          terranixConfiguration = a: a;
          system = "sx";
          name = _: "dns";
        }
        {
          scope.name = "prod";
          sinks.t = [ "m" ];
        }
      ).terraformConfigurations.dns
      )
      ({
        system = "sx";
        modules = [ "m" ];
      });
  distributed-nodes =
    eq
      (bat.distributed.nodes { from.__sink = "n"; } {
        scope.name = "web";
        sinks.n = [
          { value.web = "m1"; }
          { value.db = "m2"; }
        ];
      })
      ({
        imports = [ "m1" ];
      });
  configurations =
    eq
      (bat.configurations
        {
          from.__sink = "m";
          output = "xConfigurations";
          build = s: ms: {
            inherit (s) name;
            inherit ms;
          };
        }
        {
          scope.name = "h";
          sinks.m = [ "a" ];
        }
      )
      ({
        xConfigurations.h = {
          name = "h";
          ms = [ "a" ];
        };
      });
  darwin-system =
    eq
      ((bat.darwin.system
        {
          from.__sink = "d";
          darwinSystem = m: a: a // { by = m.name; };
          system = m: m.sys;
        }
        {
          scope = {
            name = "mac";
            sys = "aarch64-darwin";
          };
          sinks.d = [ "x" ];
        }
      ).darwinConfigurations.mac
      )
      ({
        system = "aarch64-darwin";
        modules = [ "x" ];
        by = "mac";
      });
  darwin-primary-user = {
    t1 = eq ((bat.darwin.primary-user { user = m: m.o; } { scope.o.name = "ana"; }).system.primaryUser
    ) ("ana");
    t2 = eq ((bat.darwin.primary-user { user = _: null; } { scope = { }; }).system.primaryUser) (
      "root"
    );
    # the twins take the same `user`, and by default the scope itself
    t3 = eq ((bat.darwin.primary-user { } { scope.name = "ana"; }).system.primaryUser) "ana";
    nixos-default = eq (b.attrNames (bat.nixos.primary-user { } { scope.name = "ana"; }).users.users) [
      "ana"
    ];
    nixos-ref = eq (b.attrNames
      (bat.nixos.primary-user { user = m: m.o; } { scope.o.name = "bo"; }).users.users
    ) [ "bo" ];
    nixos-null = eq (bat.nixos.primary-user { user = _: null; } { scope = { }; }) { };
  };
  darwin-homebrew =
    eq
      ((bat.darwin.homebrew { from.__sink = "b"; } {
        sinks.b = [
          { casks = [ "a" ]; }
          {
            casks = [ "a" ];
            brews = [ "jq" ];
            masApps.X = 1;
          }
        ];
      }).homebrew
      )
      ({
        enable = true;
        casks = [ "a" ];
        brews = [ "jq" ];
        masApps.X = 1;
      });
  home-manager-system =
    eq
      ((bat.home-manager.system
        {
          from.__sink = "h";
          homeManagerConfiguration = _: a: a;
          pkgs = h: "pkgs-${h.name}";
        }
        {
          scope.name = "ana";
          sinks.h = [ "m" ];
        }
      ).homeConfigurations.ana
      )
      ({
        pkgs = "pkgs-ana";
        modules = [ "m" ];
      });
  home-manager-into-host =
    eq
      (bat.home-manager.into-host { from.__sink = "h"; } {
        scope.name = "ana";
        sinks.h = [ "m" ];
      })
      ({
        home-manager.users.ana.imports = [ "m" ];
      });
  droid = {
    t1 = eq ((bat.droid.system
      {
        from.__sink = "d";
        nixOnDroidConfiguration = a: a;
        pkgs = _: "p";
      }
      {
        scope.name = "pixel";
        sinks.d = [ "m" ];
      }
    ).nixOnDroidConfigurations.pixel.modules
    ) ([ "m" ]);
    t2 = eq (bat.droid.home { from.__sink = "h"; } { sinks.h = [ "hm" ]; }) ({
      home-manager.config.imports = [ "hm" ];
    });
  };
  microvm-guest =
    eq
      (bat.microvm.guest
        {
          from.__sink = "n";
          pkgs = g: "p-${g.name}";
        }
        {
          scope.name = "ci";
          sinks.n = [ "m" ];
        }
      )
      ({
        microvm.vms.ci = {
          pkgs = "p-ci";
          config.imports = [ "m" ];
        };
      });
  nixos-user-shell = {
    t1 =
      eq
        (
          (nixos.user-shell { shell = u: u.sh; } {
            scope = sc "ana" // {
              sh = "fish";
            };
          } { pkgs.fish = "F"; })
        )
        ({
          users.users.ana.shell = "F";
          programs.fish.enable = true;
        });
    t2 = no (
      ((nixos.user-shell { shell = _: "bash"; } { scope = sc "bob"; } { pkgs.bash = "B"; }) ? programs)
    );
  };
  nixos-autologin = {
    t1 =
      eq
        (nixos.autologin { user = h: h.u; } {
          scope = sc "h" // {
            u = {
              name = "ana";
            };
          };
        })
        ({
          services.getty.autologinUser = "ana";
        });
    t2 = eq (nixos.autologin { user = _: null; } { scope = sc "h"; }) ({ });
  };
  nixos-firewall =
    eq
      (nixos.firewall { from.__sink = "p"; } {
        sinks.p = [
          22
          { udp = [ 53 ]; }
          {
            tcp = [
              22
              80
            ];
          }
        ];
      })
      ({
        networking.firewall = {
          allowedTCPPorts = [
            22
            80
          ];
          allowedUDPPorts = [ 53 ];
        };
      });
  nixos-persist =
    eq
      (nixos.persist { from.__sink = "p"; } {
        sinks.p = [
          "/var/lib/x"
          { files = [ "/etc/machine-id" ]; }
          "/var/lib/x"
        ];
      })
      ({
        environment.persistence."/persist" = {
          directories = [ "/var/lib/x" ];
          files = [ "/etc/machine-id" ];
        };
      });
  nixos-persist-hide-mounts =
    eq
      (nixos.persist
        {
          from.__sink = "p";
          hideMounts = true;
        }
        {
          sinks.p = [ "/var/lib/x" ];
        }
      )
      ({
        environment.persistence."/persist" = {
          directories = [ "/var/lib/x" ];
          files = [ ];
          hideMounts = true;
        };
      });
  nixos-hosts =
    eq
      (nixos.hosts { from.__sink = "p"; } {
        scope = sc "d"; # sees both; only a has a key
        sinks.p = peers;
      })
      ({
        networking.hosts = {
          "10.0.0.1" = [ "a" ];
          "10.0.0.2" = [ "c" ];
        };
        programs.ssh.knownHosts.a = {
          hostNames = [
            "a"
            "10.0.0.1"
          ];
          publicKey = "ka";
        };
      });
  nixos-remote-builders = eq (map (m: m.hostName)
    (nixos.remote-builders
      {
        from.__sink = "b";
        systemOf = _: "x86_64-linux";
      }
      {
        scope = sc "a";
        sinks.b = builders;
      }
    ).nix.buildMachines
  ) ([ "d" ]);
  nixos-facter = {
    t1 =
      eq
        (nixos.facter {
          report = h: "/r/${h.name}.json";
          module = "M";
        } { scope = sc "h"; })
        ({
          facter.reportPath = "/r/h.json";
          imports = [ "M" ];
        });
    t2 = eq (nixos.facter { report = h: "/r/${h.name}.json"; } { scope = sc "h"; }) ({
      hardware.facter.reportPath = "/r/h.json";
    });
  };
  unfree = {
    t1 = eq (unfreeR.errors) ([ ]);
    t2 = yes (pred {
      pname = "steam";
    });
    t3 = yes (pred {
      pname = "vscode";
    });
    t4 = no ((pred { pname = "zoom"; }));
    t5 = no ((unfreeR.flake.sys ? c)); # a sink with no elements gives nothing
  };
  install-apps =
    let
      pkgs = {
        lib.escapeShellArg = s: "'${s}'";
        stdenv.hostPlatform.system = "x86_64-linux";
        writeShellScript = _: t: t;
        nixos-anywhere = "NA";
      };
      app = bat.install.apps {
        from.__sink = "d";
        inherit pkgs;
        flake = "git";
        report = h: "./hw/${h.name}.json";
        target = h: "root@${h.name}";
      };
      got = app {
        scope.name = "lb";
        sinks.d.disk = { };
      };
    in
    {
      t1 = eq (b.attrNames got.apps.x86_64-linux) ([ "install-lb" ]);
      t2 = yes (
        b.match
          ".*NA/bin/nixos-anywhere --flake 'git#lb'.*nixos-facter './hw/lb.json'.*--target-host 'root@lb'.*"
          (b.replaceStrings [ "\n" ] [ " " ] got.apps.x86_64-linux.install-lb.program) != null
      );
      t3 = eq (app {
        scope.name = "lb";
        sinks.d = { };
      }) ({ });
    };
  deploy-rebuild =
    let
      pkgs = {
        lib.escapeShellArg = s: "'${s}'";
        stdenv.hostPlatform.system = "x86_64-linux";
        writeShellScript = _: t: t;
        nixos-rebuild = "NR";
      };
      app = bat.deploy.rebuild {
        from.__sink = "p";
        inherit pkgs;
        flake = "git";
      };
      text =
        d:
        b.replaceStrings [ "\n" ] [ " " ] (
          (app {
            scope.name = "web";
            sinks.p = d;
          }).apps.x86_64-linux.rebuild-web.program
        );
      host = {
        user = "deploy";
        address = "10.0.0.2";
      };
    in
    {
      t1 = yes (
        b.match
          ".*NR/bin/nixos-rebuild switch --flake 'git#web'.*--target-host 'deploy@10.0.0.2' --build-host 'b' .*"
          (text (host // { buildHost = "b"; })) != null
      );
      t2 = no (b.match ".*build-host.*" (text (host // { buildHost = null; })) != null);
      t3 = eq (app {
        scope.name = "web";
        sinks.p = null;
      }) ({ });
      # the shell quoting is the battery's own (no nixpkgs lib): a quote in a value is closed, escaped, reopened
      t4 = yes (b.match ".*--build-host 'a'.''b' .*" (text (host // { buildHost = "a'b"; })) != null);
    };
}
