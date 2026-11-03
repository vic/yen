# The sinks battery oracles: tests.sinks.<test> = { expr; expected; }. Run them: fastest --flake .#tests sinks
self:
let
  inherit (self.tests._batteries)
    b
    bat
    claimBad
    claimOk
    claimRank
    codes
    eq
    functorR
    meshR
    orderedCycle
    orderedOk
    orderedTypo
    reserved
    reservedField
    sinkRefs
    viewR
    yes
    ;
in
{
  # #97: a sink at a system scope as flake.<group>.<system>, and the inputs read at one system
  per-system =
    let
      p = bat.perSystem;
      ins = {
        a = {
          packages.x.hello = 1;
          legacyPackages.x = {
            hello = 0;
            vim = 2;
          };
        };
        b.packages.y.z = 3;
      };
    in
    {
      out = eq (p.out
        {
          from.__sink = "packages";
          group = "packages";
        }
        {
          scope.name = "x";
          sinks.packages.hello = 1;
        }
      ) { packages.x.hello = 1; };
      # packages wins over legacyPackages; an input without the system gives { }
      inputs =
        eq
          (p.inputs {
            inputs = ins;
            system = "x";
          })
          {
            a = {
              hello = 1;
              vim = 2;
            };
            b = { };
          };
    };
  imports-battery = eq (bat.imports { from.__sink = "s"; } { sinks.s = [ "m" ]; }) ({
    imports = [ "m" ];
  });
  maybe-ref-schema = eq (viewR.schema.kinds.person.fields.home.ref or null) ("box");
  addresses =
    let
      a = bat.addresses;
    in
    {
      t1 =
        eq
          (a {
            prefix = "10.8.0.0/24";
            members = [
              { name = "lb"; }
              {
                name = "web";
                address = "10.8.0.1";
              }
              { name = "db"; }
            ];
          })
          ({
            value = {
              lb = "10.8.0.2";
              web = "10.8.0.1";
              db = "10.8.0.3";
            };
            errors = [ ];
          });
      t2 = eq (map (e: e.code)
        (a {
          prefix = "10.8.0.0/24";
          members = [
            {
              name = "a";
              address = "10.8.0.5";
            }
            {
              name = "b";
              address = "10.8.0.5";
            }
          ];
        }).errors
      ) ([ "addresses-twice" ]);
      t3 = eq (map (e: e.got)
        (a {
          prefix = "10.8.0.0/24";
          members = map (i: { name = "m${toString i}"; }) (b.genList (i: i) 255);
        }).errors
      ) ([ [ "m254" ] ]);
      t4 = eq (map (e: e.code)
        (a {
          prefix = "10.8.0.0/30";
          members = [ ];
        }).errors
      ) ([ "addresses-prefix" ]);
      # /8 and /15 are too wide: the `>= 16` lower bound
      t5 =
        eq
          (map
            (
              p:
              map (e: e.code)
                (a {
                  prefix = p;
                  members = [ ];
                }).errors
            )
            [
              "10.0.0.0/8"
              "10.8.0.0/15"
              "10.8.0.0/16"
            ]
          )
          ([
            [ "addresses-prefix" ]
            [ "addresses-prefix" ]
            [ ]
          ]);
    };
  mesh = {
    t1 = eq (meshR.errors) ([ ]);
    t2 = eq (meshR.flake.sys) ({
      a = [ { peers = [ "c" ]; } ];
      c = [
        {
          peers = [
            "a"
            "p"
          ];
        }
      ];
    });
  };
  claim = eq (claimOk.flake.got) ({
    "10.0.0.1".addr = "10.0.0.1";
    "10.0.0.2".addr = "10.0.0.2";
  });
  claim-two-owners = {
    t1 = eq (codes claimBad) ([ "claim" ]);
    t2 = eq (builtins.attrNames claimBad.flake) ([ "invalid-flake-errors" ]);
  };
  claim-rank = {
    t1 = eq (claimRank.errors) ([ ]);
    t2 = eq (claimRank.flake.got.gpu0.prio) (9);
  };
  ordered = eq (orderedOk.flake.got) ([
    "H"
    "T"
    "B"
    "F"
  ]);
  ordered-cycle = eq (codes orderedCycle) ([ "ordered-cycle" ]);
  ordered-unknown = eq (codes orderedTypo) ([ "ordered-unknown" ]);
  sink-name-and-sinks-arg = {
    t1 = eq (sinkRefs.errors) ([ ]);
    t2 = eq (sinkRefs.flake.sys.a) ([
      {
        seen = [ "steam" ];
        hasSys = true;
        hasOut = true;
        name = "names";
      }
    ]);
  };
  sink-named-sinks = yes (b.any (e: (e.code or null) == "reserved") reserved.errors);
  field-named-key = yes (
    b.any (
      e:
      (e.code or null) == "reserved"
      &&
        e.path or null == [
          "box"
          "key"
        ]
    ) reservedField.errors
  );
  functor = eq (functorR.flake.sys.c) ([ "at c" ]);
}
