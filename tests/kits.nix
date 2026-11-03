# The kits battery oracles: tests.kits.<test> = { expr; expected; }. Run them: fastest --flake .#tests kits
self:
let
  inherit (self.tests._batteries)
    aMain
    b
    bat
    eq
    hA
    hC
    kContract
    kDb
    kHolds
    kIs
    kRef
    kt
    no
    usersR
    yes
    ;
in
{
  # a kit's parts live under their assembly, at every depth; a name two assemblies share is an error
  kit-parts =
    let
      leaf = {
        roles.default = { };
      };
      mid = leaf // {
        adds = _: {
          leaf = {
            kit = leaf;
            roles.default.at = [ ];
          };
        };
      };
      top = leaf // {
        adds = _: {
          mid = {
            kit = mid;
            roles.default.at = [ ];
          };
        };
      };
      all = bat.kits.assemblies [
        {
          name = "lab";
          kit = top;
          roles.default.at = [ ];
        }
      ];
      clash = bat.kits.contract {
        assemblies = all ++ [
          {
            name = "lab-mid";
            kit = leaf;
            roles.default.at = [ ];
          }
        ];
        machines = [ ];
        holds = _: _: false;
      };
    in
    {
      names = eq (map (a: a.name) all) [
        "lab"
        "lab-mid"
        "lab-mid-leaf"
      ];
      paths = eq (map (a: a.path or [ a.name ]) all) [
        [ "lab" ]
        [
          "lab"
          "mid"
        ]
        [
          "lab"
          "mid"
          "leaf"
        ]
      ];
      clash = yes (b.any (e: b.match ".*have one name: lab-mid.*" e != null) clash);
    };
  exports-modules =
    eq
      (bat.exports.modules
        {
          from.__sink = "os";
          output = "homeModules";
        }
        {
          scope.name = "base";
          sinks.os = [ "m" ];
        }
      )
      ({
        homeModules.base.imports = [ "m" ];
      });
  kits-members =
    let
      ms = kt.members {
        assemblies = [ aMain ];
        holds = kHolds;
      } hA;
      m = ms."main.server";
    in
    {
      t1 = eq (b.attrNames ms) ([ "main.server" ]);
      t2 = eq (m.assembly.name) ("main");
      t3 = eq (m.kit.name) ("db");
      t4 = eq (m.role) ("server");
      t5 = eq (m.settings) ({ port = 1; });
    };
  kits-members-default-settings =
    eq
      ((kt.members {
        assemblies = [ (aMain // { roles.server.at = m: m.db; }) ];
        holds = kHolds;
      } hA)."main.server".settings
      )
      ({
        port = 5432;
      });
  kits-members-none = eq (kt.members {
    assemblies = [ aMain ];
    holds = kHolds;
  } (kRef "host" "z" // { db = false; })) ({ });
  kits-contract-ok = eq (kContract [ aMain ]) ([ ]);
  kits-contract-min = eq (kContract [
    (
      kRef "assembly" "x"
      // {
        kit = kDb;
        roles.server.at = _: false;
      }
    )
  ]) ([ "kits: assembly x role server: 0 machines, at least 1" ]);
  kits-contract-unknown-role = eq (kContract [
    (
      kRef "assembly" "x"
      // {
        kit = kDb;
        roles.server.at = kIs hA;
        roles.ghost.at = kIs hA;
      }
    )
  ]) ([ "kits: assembly x: kit db has no role ghost" ]);
  kits-contract-string-kit = eq (kContract [
    (
      kRef "assembly" "x"
      // {
        kit = "db";
        roles.server.at = kIs hA;
      }
    )
  ]) ([ "kits: assembly x: kit is a string, not a kit" ]);
  kits-contract-string-at = eq (kContract [
    (
      kRef "assembly" "x"
      // {
        kit = kDb;
        roles.server.at = "a";
      }
    )
  ]) ([ "kits: assembly x role server: `at` is a string, not a predicate" ]);
  kits-contract-max-assemblies = eq (b.length (kContract [
    aMain
    (aMain // { name = "two"; })
  ])) (2);
  kits-exports =
    let
      member = h: {
        kind = "member";
        assembly = aMain;
        kit = kDb;
        role = "server";
        parent = h;
      };
      r = kt.exports { isMember = s: s.kind or null == "member"; } [
        {
          from = member hA;
          value.endpoint = "a:1";
        }
        {
          from = member hC;
          value.secret = "x";
        }
        {
          from = kRef "fleet" "f";
          value = {
            assembly = aMain;
            role = "server";
            machine = hA;
            value.endpoint = "over";
          };
        }
      ];
    in
    {
      t1 = eq ((b.head r.value).value.endpoint) ("over");
      t2 = eq (map (e: e.error) r.errors) ([ "kits: main.server@c: kit db does not export secret" ]);
    };
  users = {
    t1 = eq (usersR.errors) ([ ]);
    t2 = eq (usersR.flake.sys.a) ([
      { networking.hostName = "a"; }
      {
        users.users.p = {
          isNormalUser = true;
          home = "/home/p";
        };
      }
      {
        users.users.p.extraGroups = [
          "wheel"
          "networkmanager"
        ];
      }
    ]);
    t3 = no ((usersR.flake.sys ? c));
  };
  # install and deploy: a fake pkgs whose script is its text
  disko-devices = {
    t1 = eq (bat.disko { from.__sink = "d"; } {
      sinks.d = {
        disk.main.device = "/dev/x";
      };
    }) ({ disko.devices.disk.main.device = "/dev/x"; });
    t2 = eq (bat.disko { from.__sink = "d"; } { sinks.d = { }; }) ({ });
  };
}
