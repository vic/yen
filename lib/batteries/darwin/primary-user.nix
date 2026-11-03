#: lib.batteries.darwin.primary-user :: { user ? ; } -> key value -- system.primaryUser is the user that user reads (null: root)
# system.primaryUser (the user that user-level options such as the dock apply to): `user` reads a ref (its name) or a
# name from the scope; null falls back to root. By default the user is the scope itself, as in `nixos.primary-user`.
#   darwin = darwin.primary-user { user = m: m.system-owner; };
self:
{
  user ? (s: s),
}:
{ scope, ... }:
let
  name = self._core.helpers.nameOf (user scope);
in
{
  system.primaryUser = if name == null then "root" else name;
}
