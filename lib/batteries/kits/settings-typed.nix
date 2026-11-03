#: lib.batteries.kits.settings-typed :: { scope; } -> [ error ] -- each setting of the member role is set and passes its type
# at a member scope (from kits.members), the value of an `errors` key: each setting of its role's interface must be
# set and pass the option's type.
#   yen.aspects.settings-typed = { at = yen.kinds.member; errors = kits.settings-typed; };
self:
{ scope, ... }:
let
  b = builtins;
  inherit (self._core.types) typeName checkOf;
  iface = scope.kit.roles.${scope.role}.interface or { };
in
b.concatMap (
  k:
  let
    o = iface.${k};
    v = scope.settings.${k};
  in
  if v == null || !checkOf o.type v then
    [ "kits: ${scope.assembly.name}.${scope.role}: setting ${k} is not a ${typeName o.type}" ]
  else
    [ ]
) (b.attrNames iface)
