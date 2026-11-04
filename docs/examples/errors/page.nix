{
  title = "Errors as data";
  description = "yen never throws. Errors are records that prove what failed; your own checks add to them.";
  section = "principles";
  order = 2;

  body =
    {
      docs,
      result,
      variant,
      ...
    }:
    [
      ''
        yen never calls `throw`. When something is wrong, the read gives `null`, evaluation continues,
        and the `errors` [query](/query/queries/) lists a record. An empty list means the fleet is valid.

        ## Error records

        A host with a field name that does not exist, `bakup` for `backup`, gives an error record:
      ''
      (docs.file "variants/typo.nix")
      (docs.value (variant "variants/typo.nix").errors)
      ''
        Each record has `error` and `from` for people, and `code`, `path`, `got`, `want`, `fix`, `class` and `near`
        for tools and agents. `class` is `fixable` when an edit to the data fixes it, and `authority` when no edit
        by this author can. `near` lists the fields you may have meant. The [error reference](/reference/errors/)
        lists every `code`.

        ## Your own checks

        An aspect key `errors` gives records, or plain messages. This fleet has three hosts, and each host has an address:
      ''
      (docs.fileNoted "" "modules/fleet.nix")
      ''
        At `(1)`, a `warnings` sink: see Warnings below. At `(2)`, `backup` is a field of every host, `true` unless the host says otherwise.

        The [aspect](/behavior/aspects/) `unique-addr` checks that no two hosts share an address. It asks the
        [cycle](/behavior/cycle/) for a tree of all hosts:
      ''
      (docs.fileNoted "{9-16}" "modules/checks.nix")
      ''
        At `(1)`, a tree request: it asks for every host with its data. At `(2)`, the aspect is active at the fleet only,
        so the check runs once. At `(3)`, the key `errors` gives the records. yen sets `from` to the scope that gave them:
        an aspect cannot report for another scope. At `(4)`, `code` names the failure. A record without `class` is `fixable`.

        A new host with the address of `web` gives an error record:
      ''
      (docs.file "variants/duplicate.nix")
      (docs.value (variant "variants/duplicate.nix").errors)
      ''
        A fleet with an error gives no outputs. Its `flake` is `{ invalid-flake-errors = { errors; violations; incomplete; }; }`
        until `errors` is `[ ]` and every [invariant](/query/invariants/) holds: a build finds no output, and `nix eval .#invalid-flake-errors`
        tells you, or an agent, why:
      ''
      (docs.value (variant "variants/duplicate.nix").flake)
      ''
        ## Warnings

        A warning is a message that does not fail the fleet. At `(5)` in `modules/checks.nix`, the aspect `no-backup` gives
        one for each host without a backup. The `warnings` sink at `(1)` in `modules/fleet.nix` hands them to the flake:
      ''
      (docs.value result.flake.warnings)
      (docs.tip "Gate CI on it" ''
        In CI, fail when `errors` is not `[ ]`, before any build. A `query.nix` gives every query on the command line:
        see [Project layout](/start/project-layout/).
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
      duplicate =
        eq
          (map (e: {
            inherit (e)
              code
              error
              from
              class
              ;
          }) (variant "variants/duplicate.nix").errors)
          ([
            {
              code = "duplicate-addr";
              error = "10.0.0.1 is the address of cache and web";
              from = "fleet:main";
              class = "fixable";
            }
          ]);
      # only the reason, and the Lean check that fails on it
      no-outputs = eq (builtins.attrNames (variant "variants/duplicate.nix").flake) ([
        "checks"
        "invalid-flake-errors"
      ]);
      warnings = eq (result.flake.warnings) ([ "scratch has no backup" ]);
      typo = yes (
        builtins.any (e: e.code == "unknown-field" && e.near == [ "backup" ])
          (variant "variants/typo.nix").errors
      );
    };
}
