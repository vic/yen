# The vars battery oracles: tests.vars.<test> = { expr; expected; }. Run them: fastest --flake .#tests vars
self:
let
  inherit (self.tests._batteries)
    b
    badDeps
    eq
    gen
    gens
    kh
    khArgs
    plan
    pub
    secretReads
    ;
in
{
  vars-generators = {
    t1 = eq (b.attrNames gens.value) ([
      "borg@a"
      "ssh@a"
      "ssh@c"
      "wifi"
    ]);
    t2 = eq (gens.value.wifi.machines) ([
      "a"
      "c"
    ]);
    t3 = eq (gens.errors) ([ ]);
    # an element may give a list of generators
    t4 =
      eq
        (b.attrNames
          (gen [
            {
              m = "a";
              v = [
                {
                  name = "p";
                  files = { };
                }
                {
                  name = "q";
                  share = true;
                  files = { };
                }
                null # a null in a list gives nothing, as a null element does
              ];
            }
          ]).value
        )
        ([
          "p@a"
          "q"
        ]);
  };
  # a dependency cycle on one machine has no generation order: an error with the code `ordered` gives (GH #68)
  vars-generators-cycle =
    eq
      (map (e: { inherit (e) code got; }) (
        (gen [
          {
            m = "a";
            v = [
              {
                name = "x";
                dependencies = [ "y" ];
              }
              {
                name = "y";
                dependencies = [ "x" ];
              }
            ];
          }
        ]).errors
      ))
      ([
        {
          code = "ordered-cycle";
          got = [
            "x"
            "y"
          ];
        }
      ]);
  vars-generators-dependency = eq (map (e: e.error) badDeps.errors) ([
    "vars: generator borg@c depends on nope, which c has not"
  ]);
  vars-vars-plan = {
    t1 = eq (map (g: g.name) plan.order) ([
      "ssh"
      "borg"
      "wifi"
    ]);
    t2 = eq (map (f: f.path) plan.files) ([
      "/run/secrets-for-users/vars/borg/pass"
      "/run/secrets/vars/ssh/key"
      "/run/secrets/vars/wifi/pw"
    ]);
    t3 = eq (plan.recipients) ([ "r-a" ]);
  };
  vars-secret-reads = eq (secretReads) ([ "vars: a reads ssh/key, a secret file" ]);
  vars-public-value = {
    t1 = eq (pub "lb" "openssh" "key.pub" "absent") ("ssh-ed25519 PUB");
    t2 = eq (pub "lb" "openssh" "nope" "absent") ("absent");
  };
  vars-known-hosts = {
    t1 = eq ((kh.nixos khArgs).programs.ssh.knownHosts) ({
      lb = {
        hostNames = [ "lb" ];
        publicKey = "ssh-ed25519 PUB";
      };
    });
    t2 = eq (map (e: e.error) (kh.errors khArgs)) ([
      "known-hosts: nope has no openssh/key.pub public key"
    ]);
  };
}
