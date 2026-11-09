{
  title = "Assemblies and roles";
  description = "Assemblies as data: each machine gets one member scope per role, and members exchange data.";
  section = "recipes";
  order = 9;
  badge = "advanced";

  body =
    { docs, result, ... }:
    [
      ''
        A backup has roles: one server and many clients. An assembly says which machine takes which role, using
        [refs](/model/instances-refs/):
      ''
      (docs.fileNoted "" "modules/inventory.nix")
      ''
        At `(1)`, the assembly `backup` has `roles`. At `(2)`, `server` lists one machine and `client` lists two.

        Each machine spawns one `member` [scope](/model/scopes/) for every (assembly, role) pair it takes part in. This
        kind file does it:
      ''
      (docs.fileNoted "{12-16,34}" "modules/kinds.nix")
      ''
        At `(1)`, for each assembly and each of its roles, the machine looks for itself in that role's list. At `(2)`, the
        member holds a ref to its assembly, and at `(4)`, `spawns.member` creates the members. At `(3)`, the `exports` sink
        collects what members publish. An aspect at a member scope runs once for each assembly and role, while an aspect at
        a machine that has a member runs once for each machine. The scopes:
      ''
      (docs.scopes result)
      ''
        ## Members exchange data

        Clients publish their address to a fleet sink with `elements`. The engine sets `from`, so a member can only publish
        as itself. The server reads those elements and builds its allow list:
      ''
      (docs.fileNoted "{9,17}" "modules/backup.nix")
      ''
        At `(1)`, an [aspect](/behavior/aspects/) is active only at members of the `backup` assembly with a given role.
        At `(2)`, the client publishes its address with the `exports` key. The result:
      ''
      (docs.value result.flake.config)
      (docs.tip "The full model" ''
        [Kits batteries](/batteries/kits/) go further: kits as data with typed role settings and errors, `at` predicates
        as role members, exports with owner overrides, and vars generators. The
        [reference fleet](https://github.com/vic/yen/blob/main/reference/modules/kits/assemblies.nix) uses all of them.
      '')
    ];

  checks =
    {
      result,
      eq,
      yes,
      no,
      ...
    }:
    {
      allow = eq (result.flake.config.nas.backup.allow) ([
        "10.0.0.1"
        "10.0.0.2"
      ]);
      members = eq (map (s: s.id) (builtins.filter (s: s.kind == "member") result.scopes)) ([
        "fleet:main/host:db/member:backup.client"
        "fleet:main/host:nas/member:backup.server"
        "fleet:main/host:web/member:backup.client"
      ]);
    };
}
