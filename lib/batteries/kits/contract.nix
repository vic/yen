#: lib.batteries.kits.contract :: { assemblies; machines; holds; } -> [ error ] -- the assembly contract: roles, machine counts, assemblies per kit
# the assembly contract, the value of an `errors` key: the kit is a kit, every role is the kit's and its `at` is a
# predicate, the machine count per role is within the kit's `constraints.roles.<role>.{min,max}`, and at most
# `constraints.maxAssemblies` assemblies use one kit, and no two assemblies share a name (a part a kit adds included).
#   errors = kits.contract { assemblies = attrValues yen.assembly; machines = attrValues yen.host; inherit (yen.lib) holds; };
self:
{
  assemblies,
  machines,
  holds,
}:
let
  b = builtins;
  inherit (self._roles) takes;
  isPredicate = p: b.isFunction p || b.isList p || b.isAttrs p;
  same = x: y: b.isAttrs x && x.kind or null == y.kind or null && x.name or null == y.name or null;
  when = cond: msg: if cond then [ msg ] else [ ];
  at = a: r: a.roles.${r}.at or null;
  known = k: r: k.roles ? ${r};
  count = a: r: b.length (b.filter (takes holds a.roles.${r}) machines);
  # k: the kit of a, c: its constraints
  check = a: checkKit a a.kit (a.kit.constraints or { });
  checkKit =
    a: k: c:
    if !(b.isAttrs k && k ? roles) then
      [ "kits: assembly ${a.name}: kit is a ${b.typeOf k}, not a kit" ]
    else
      checkRoles a k c (b.attrNames a.roles);
  # roles: the role names of a
  checkRoles =
    a: k: c: roles:
    when (roles == [ ]) "kits: assembly ${a.name} has no roles"
    ++ map (r: "kits: assembly ${a.name}: kit ${k.name} has no role ${r}") (
      b.filter (r: !known k r) roles
    )
    ++ map (r: "kits: assembly ${a.name} role ${r}: `at` is a ${b.typeOf (at a r)}, not a predicate") (
      b.filter (r: !isPredicate (at a r)) roles
    )
    ++ b.concatMap (r: limits a r (count a r) (c.roles.${r} or { })) (
      b.filter (r: known k r && isPredicate (at a r)) roles
    )
    ++ when (
      c ? maxAssemblies && b.length (b.filter (x: same x.kit k) assemblies) > c.maxAssemblies
    ) "kits: assembly ${a.name}: kit ${k.name} allows ${toString c.maxAssemblies} assemblies";
  # n: the machines of role r, lim: the role's min and max
  limits =
    a: r: n: lim:
    when (
      lim ? min && n < lim.min
    ) "kits: assembly ${a.name} role ${r}: ${toString n} machines, at least ${toString lim.min}"
    ++ when (
      lim ? max && n > lim.max
    ) "kits: assembly ${a.name} role ${r}: ${toString n} machines, at most ${toString lim.max}";
  # two assemblies with one name: a part a kit adds and an assembly the fleet writes, or two parts
  byName = b.groupBy (a: a.name) assemblies;
  clashes = b.filter (n: b.length byName.${n} > 1) (b.attrNames byName);
  pathOf = a: b.concatStringsSep "/" (a.path or [ a.name ]);
in
b.concatMap check assemblies
++ map (
  n: "kits: assemblies ${b.concatStringsSep " and " (map pathOf byName.${n})} have one name: ${n}"
) clashes
