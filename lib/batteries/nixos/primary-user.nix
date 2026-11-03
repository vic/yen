#: lib.batteries.nixos.primary-user :: { user ? ; } -> key value -- the account of the user that user reads administers the machine
# the account of the user that `user` reads from the scope administers the machine (Den's primary-user): a ref (its
# name) or a name; null is nobody. By default the user is the scope itself. `darwin.primary-user` takes the same `user`.
#   yen.aspects.admin = { at = yen.user.ana; nixos = nixos.primary-user { }; };
self:
{
  user ? (s: s),
}:
{ scope, ... }:
let
  name = self._core.helpers.nameOf (user scope);
in
if name == null then
  { }
else
  {
    users.users.${name}.extraGroups = [
      "wheel"
      "networkmanager"
    ];
  }
