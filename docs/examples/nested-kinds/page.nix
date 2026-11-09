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
        A [kind](/model/kinds-fields/) can declare kinds inside it. A nested kind has no name of its own at the top,
        because its instances live under one instance of the parent. A host's user is a good example.

        You write the nested kind in the parent's `kinds` key:
      ''
      (docs.fileNoted "" "modules/host.nix")
      ''
        `(1)` declares the `user` kind inside `host`. There's no `yen.kinds.user`; the path is `yen.kinds.host.kinds.user`.

        ## Instances

        You write a nested kind's instances inside the parent's instance:
      ''
      (docs.fileNoted "" "modules/hosts.nix")
      ''
        `(1)` is the user `vic` of the host `laptop`, `yen.host.laptop.user.vic`, and `(2)` is the user `vic` of the host
        `server`. Two hosts can each have a user `vic`, and they're two different instances.

        ## Refs

        A nested kind's ref has the same path as its declaration. The [aspect](/behavior/aspects/) below
        gives one line per user:
      ''
      (docs.fileNoted "" "modules/report.nix")
      (docs.value result.flake.report)
      ''
        `(1)` is the nested kind's ref, and `(2)` reads the current [scope](/model/scopes/) with the `scope` arg.
        A scope's `id` shows the parent, since a user's scope is a child of its host's scope.

        The `{ user, ... }` arg works too, because a function arg can name a nested kind by its leaf name.
        Yen resolves the name up the ancestors only, never a sibling. The root kind that collects `report` is in
        [the example code](https://github.com/vic/yen/tree/main/docs/examples/nested-kinds/modules/fleet.nix).

        ## Spawns

        A kind spawns its nested kinds by default, from the key with the same name. Here `host` spawns the users
        you write in it, and you don't write `spawns.user`.

        An explicit `spawns.user` replaces the default. This one keeps only `vic`:
      ''
      (docs.file "variants/explicit-spawns.nix")
      (docs.value (variant "variants/explicit-spawns.nix").flake.report)
      ''
        Use a nested kind for children that exist under one parent. A kind that nothing spawns, like a type for
        data, stays a flat kind at the top.

        ## Same result as flat kinds

        This page's check evaluates the same fleet with flat kinds, where `user` is a top kind and `host` spawns
        it by hand. The scopes and the report are equal; the nested form just keeps `user` out of the top names:
      ''
      (docs.file "flat/host.nix")
      ''
        ## Errors

        A kind's field can't have the same name as a nested kind, because both use the same path in an instance:
      ''
      (docs.file "variants/reserved.nix")
      (docs.value (variant "variants/reserved.nix").errors)
      ''
        A key the nested kind doesn't have is an unknown key, reported with the nested kind's path:
      ''
      (docs.file "variants/not-a-kind.nix")
      (docs.value (variant "variants/not-a-kind.nix").errors)
      ''
        A nested kind's instances are a set of names, so a value that isn't a set fails its type:
      ''
      (docs.file "variants/bad-group.nix")
      (docs.value (variant "variants/bad-group.nix").errors)
      (docs.note "Limits today" ''
        - A nested kind named `scope` or `sinks` can't be an arg. These names aren't reserved, but the arg always means the scope or the sinks.
        - You can't ref a nested instance by its name alone; reach it through its parent.
        - A callback like `keep = s: s.kind == "host"` drops nested scopes without a warning, because a nested scope's kind is a list and the test never matches.
        - The kinds diagram only draws top kinds, so a nested kind isn't a node there.
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
