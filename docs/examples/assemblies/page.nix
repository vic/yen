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
        A backup has roles: one server, many clients. An assembly says which machine takes which role, with [refs](/model/instances-refs/):
      ''
      (docs.fileNoted "" "modules/inventory.nix")
      ''
        At `(1)`, the assembly `backup` has `roles`. At `(2)`, `server` lists one machine. `client` lists two.

        Each machine spawns one `member` [scope](/model/scopes/) per (assembly, role) it takes part in. This kind file does it:
      ''
      (docs.fileNoted "{12-16,34}" "modules/kinds.nix")
      ''
        At `(1)`, for each assembly and each of its roles, the machine looks for itself in the list of that role.
        At `(2)`, the member holds a ref to its assembly. At `(4)`, `spawns.member` creates the members. At `(3)`, the sink `exports`
        collects what members publish. An aspect at a member scope runs once per assembly and role. An aspect at a machine that
        has a member runs once per machine. These are the scopes:
      ''
      (docs.scopes result)
      ''
        ## Members exchange data

        Clients publish their address to a fleet sink with `elements`. The engine sets `from`, so a member can only publish
        as itself. The server reads the elements and builds its allow list:
      ''
      (docs.fileNoted "{9,17}" "modules/backup.nix")
      ''
        At `(1)`, an [aspect](/behavior/aspects/) is active only at members of the assembly `backup` with a given role.
        At `(2)`, the client publishes its address with the key `exports`. The result:
      ''
      (docs.value result.flake.config)
      (docs.tip "The full model" ''
        [Kits batteries](/batteries/kits/) add kits as data with typed role settings and errors, `at` predicates as
        role members, exports with owner overrides, and vars generators. The
        [reference fleet](https://github.com/vic/yen/blob/main/reference/modules/kits/assemblies.nix) uses them.
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
