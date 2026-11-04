{
  title = "Secrets as data";
  description = "Secrets are instances of a data kind. Hosts get exactly the secrets that name them, as refs.";
  section = "recipes";
  order = 6;

  body =
    {
      docs,
      result,
      variant,
      ...
    }:
    [
      ''
        yen never reads a secret. It plans which host gets which encrypted file, as data that a secrets tool
        (agenix, sops-nix) reads. A secret is an instance of a data [kind](/model/kinds-fields/); its owners are host refs.
      ''
      (docs.fileNoted "{13-18}" "modules/kinds.nix")
      ''
        At `(1)`, `secret` is a kind with a `file` and its `owners`. Nothing spawns it, so it is only data. At `(2)`, each host has a
        `secrets` sink. At `(3)`, its `of` is the secret kind: only a ref to a secret passes. At `(4)`, the `out` function
        gives the plan that a secrets tool reads. This is the data:
      ''
      (docs.fileNoted "" "modules/data.nix")
      ''
        At `(1)`, `tls` has one owner. At `(2)`, `db-password` has two. One [cycle](/behavior/cycle/) delivers each secret to its owners.
        Another reports secrets that nobody owns:
      ''
      (docs.fileNoted "" "modules/deliver.nix")
      ''
        At `(1)`, a tree request for every secret. At `(2)`, each host gets the secrets that name it. At `(3)` and `(4)`,
        a secret with no owner is an error, not a silent leftover. The plan:
      ''
      (docs.value result.flake.secretsPlan)
      ''
        A secret that nobody owns is an error, and a fleet with an error gives no outputs (`flake` is `{ invalid-flake-errors = … }`, the reason):
      ''
      (docs.file "variants/orphan.nix")
      (docs.value {
        errors = map (e: e.error) (variant "variants/orphan.nix").errors;
        inherit (variant "variants/orphan.nix") flake;
      })
      ''
        ## Refs, not names

        The sink's `of` is the secret kind, so only a ref passes. A name is refused, with the scope and the aspect:
      ''
      (docs.file "variants/by-name.nix")
      (docs.value (map (e: e.error) (variant "variants/by-name.nix").errors))
      ''
        ## Values no answer states

        A field whose type is `yen.lib.secret t` is checked like `t`, and an aspect reads its value. No answer states it:
        facts, `data`, `scopes`, error records, the RDF export and the seal give `sha256:<hash>` instead. A rule can still
        compare two secrets, because equal values have equal hashes: "no two hosts share a token" is a rule.
      ''
      (docs.tip "Guard who may read" ''
        The plan is data, so a rule about it is a query. The [reference fleet](https://github.com/vic/yen/blob/main/reference/modules/kits/vars.nix)
        adds shared and per-machine generators, a deploy plan, and a guard that refuses a secret read by the wrong host.
      '')
    ];

  checks =
    {
      result,
      variant,
      eq,
      yes,
      no,
      ...
    }:
    {
      web = eq (map (s: s.name) result.flake.secretsPlan.web) ([
        "db-password"
        "tls"
      ]);
      orphan = {
        t1 = eq (map (e: e.error) (variant "variants/orphan.nix").errors) ([
          "secret old-token (secrets/old-token.age) has no owner"
        ]);
        t2 = eq (builtins.attrNames (variant "variants/orphan.nix").flake) ([
          "checks"
          "invalid-flake-errors"
        ]);
      };
      by-name = eq (map (e: e.code) (variant "variants/by-name.nix").errors) ([ "of" ]);
    };
}
