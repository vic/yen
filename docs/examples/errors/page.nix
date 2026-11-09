{
  title = "Errors as data";
  description = "Yen never throws. Errors are records that show what failed, and your own checks add to them.";
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
        Yen never calls `throw`. When something is wrong, the read gives `null`, evaluation keeps going, and the `errors`
        [query](/query/queries/) lists a record. An empty list means the fleet is valid.

        ## Error records

        A host with a field name that doesn't exist, `bakup` instead of `backup`, gives an error record:
      ''
      (docs.file "variants/typo.nix")
      (docs.value (variant "variants/typo.nix").errors)
      ''
        Each record has `error` and `from` for people, and `code`, `path`, `got`, `want`, `fix`, `class` and `near` for
        tools and agents. `class` is `fixable` when an edit to the data fixes it, and `authority` when no edit by this
        author can. `near` lists the fields you may have meant, and the [error reference](/reference/errors/) lists every `code`.

        ## Your own checks

        An aspect's `errors` key gives records or plain messages. This fleet has three hosts, each with an address:
      ''
      (docs.fileNoted "" "modules/fleet.nix")
      ''
        At `(1)` is a `warnings` sink, more on that below. At `(2)`, `backup` is a field of every host, `true` unless the
        host says otherwise.

        The `unique-addr` [aspect](/behavior/aspects/) checks that no two hosts share an address, by asking the
        [cycle](/behavior/cycle/) for a tree of all hosts:
      ''
      (docs.fileNoted "{9-16}" "modules/checks.nix")
      ''
        At `(1)`, a tree request asks for every host with its data. At `(2)`, the aspect is only active at the fleet, so
        the check runs once. At `(3)`, the `errors` key gives the records, and Yen sets `from` to the scope that gave
        them, so an aspect can't report for another scope. At `(4)`, `code` names the failure. A record without `class`
        is `fixable`.

        Add a new host with `web`'s address and you get an error record:
      ''
      (docs.file "variants/duplicate.nix")
      (docs.value (variant "variants/duplicate.nix").errors)
      ''
        A fleet with an error gives no outputs. Its `flake` stays
        `{ invalid-flake-errors = { errors; violations; incomplete; }; }` until `errors` is `[ ]` and every
        [invariant](/query/invariants/) holds. A build finds no output, and `nix eval .#invalid-flake-errors` tells you
        (or an agent) why:
      ''
      (docs.value (variant "variants/duplicate.nix").flake)
      ''
        ## Warnings

        A warning is a message that doesn't fail the fleet. At `(5)` in `modules/checks.nix`, the `no-backup` aspect gives
        one for each host without a backup, and the `warnings` sink at `(1)` in `modules/fleet.nix` hands them to the flake:
      ''
      (docs.value result.flake.warnings)
      (docs.tip "Gate CI on it" ''
        In CI, fail when `errors` isn't `[ ]`, before any build. A `query.nix` gives you every query on the command line,
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
