#: lib.batteries.kits.settings-typed :: { scope; } -> [ error ] -- each setting of the member role is set and passes its type
# at a member scope (from kits.members), the value of an `errors` key: each setting of its role's interface must be
# set and pass the option's type.
#   yen.aspects.settings-typed = { at = yen.kinds.member; errors = kits.settings-typed; };
self:
{ scope, ... }:
let
  b = builtins;
  inherit (self._core.types) checkOf typeName;
  # yen types name themselves with an article ("a string"); kind refs and nixpkgs types do not ("host ref")
  named = t: if b.match "(a|an|any) .*" (typeName t) != null then typeName t else "a ${typeName t}";
  iface = scope.kit.roles.${scope.role}.interface or { };
  # o: the option k of the interface, v: its setting
  check =
    k: o: v:
    if v == null || !checkOf o.type v then
      [ "kits: ${scope.assembly.name}.${scope.role}: setting ${k} is not ${named o.type}" ]
    else
      [ ];
in
b.concatMap (k: check k iface.${k} scope.settings.${k}) (b.attrNames iface)
