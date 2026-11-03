{
  title = "Nested kinds";
  description = "A kind declared inside another kind. Its instances live under the parent, and only the parent reaches them.";
  section = "model";
  order = 5;

  body =
    {
      docs,
      result,
      variant,
      ...
    }:
    [
      ''
        A [kind](/model/kinds-fields/) can declare kinds inside it. A user of a host is a good example: it exists only
        under its host. The nested kind `user` has no name of its own. There is no `yen.kinds.user`. Two hosts can each
        have a user `vic`: they are two instances.

        You write the nested kind in the key `kinds` of the parent:
      ''
      (docs.file "modules/host.nix")
      ''
        ## Instances

        You write the instances of a nested kind inside the instance of the parent: `yen.host.laptop.user.vic` is the
        user `vic` of the host `laptop`. The host `server` has its own user `vic`. They are two instances.
      ''
      (docs.file "modules/hosts.nix")
      ''
        ## Refs

        A ref of a nested kind has the same path as its declaration: `yen.kinds.host.kinds.user`. The aspect below
        gives one line per user. It reads the current [scope](/model/scopes/) with the arg `scope`. The arg `{ user, ... }` also works: a function arg may name a nested kind by its leaf name. The name is resolved up the ancestors only, never a sibling. The `id` of a scope shows
        the parent: the scope of a user is a child of the scope of its host.
      ''
      (docs.file "modules/report.nix")
      (docs.value result.flake.report)
      ''
        ## Spawns

        A kind spawns its nested kinds by default, from the key with the same name. Here `host` spawns the users that
        you write in it. You do not write `spawns.user`.

        An explicit `spawns.user` replaces the default. This one keeps only `vic`:
      ''
      (docs.file "variants/explicit-spawns.nix")
      (docs.value (variant "variants/explicit-spawns.nix").flake.report)
      ''
        Use a nested kind for children that exist under one parent. A kind that nothing spawns, such as a type for
        data, stays a flat kind at the top.

        ## Same result as flat kinds

        The check of this page evaluates the same fleet with flat kinds. There `user` is a top kind, and `host` spawns
        it by hand. The scopes and the report are equal. Only the nested form keeps `user` out of the top names:
      ''
      (docs.file "flat/host.nix")
      ''
        ## Errors

        A field of a kind cannot have the name of a nested kind, because both use the same path in an instance:
      ''
      (docs.file "variants/reserved.nix")
      (docs.value (variant "variants/reserved.nix").errors)
      ''
        A key that a nested kind does not have is an unknown key, with the path of the nested kind:
      ''
      (docs.file "variants/not-a-kind.nix")
      (docs.value (variant "variants/not-a-kind.nix").errors)
      ''
        The instances of a nested kind are a set of names. A value that is not a set fails its type:
      ''
      (docs.file "variants/bad-group.nix")
      (docs.value (variant "variants/bad-group.nix").errors)
      (docs.note "Limits today" ''
        - A nested kind named `scope` or `sinks` cannot be an arg. These names are not reserved, but the arg always means the scope or the sinks.
        - A ref to a nested instance by name alone is not supported: reach it through its parent.
        - A callback such as `keep = s: s.kind == "host"` drops nested scopes without a warning. The kind of a nested scope is a list, so the test never matches.
        - The kinds diagram draws top kinds only. A nested kind is not a node there.
      '')
    ];

  checks =
    {
      result,
      variant,
      only,
      eq,
      ...
    }:
    let
      flat = only [
        "modules/fleet.nix"
        "flat/host.nix"
        "flat/hosts.nix"
        "flat/report.nix"
      ];
      ids = r: map (s: s.id) r.scopes;
    in
    {
      clean = eq result.errors [ ];
      report = eq result.flake.report [
        "fleet:main/host:laptop/user:ann bash"
        "fleet:main/host:laptop/user:vic fish"
        "fleet:main/host:server/user:vic zsh"
      ];
      same-as-flat = eq (ids result) (ids flat);
      same-report = eq result.flake.report flat.flake.report;
      explicit-spawns = eq (variant "variants/explicit-spawns.nix").flake.report [
        "fleet:main/host:laptop/user:vic fish"
        "fleet:main/host:server/user:vic zsh"
      ];
    };
}
