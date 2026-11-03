#: lib.batteries.nixos.autologin :: { user; } -> key value -- tty autologin of the user that user reads
# tty autologin of the user that `user` reads from the scope: a ref (its name) or a name; null logs in nobody
# (Den's tty-autologin).
#   yen.aspects.autologin = { at = yen.kinds.host; nixos = nixos.autologin { user = h: h.autologin; }; };
self:
{ user }:
{ scope, ... }:
let
  name = self._core.helpers.nameOf (user scope);
in
if name == null then { } else { services.getty.autologinUser = name; }
