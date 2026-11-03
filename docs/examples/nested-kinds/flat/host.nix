# The same fleet with flat kinds: `user` is a top kind and host spawns it by hand.
{ yen, lib, ... }:
{
  yen.kinds.host = {
    fields.addr = yen.lib.str;
    fields.user = yen.lib.is builtins.isAttrs;
    spawns.user = s: s.user;
  };
  yen.kinds.user.fields.shell = yen.lib.str;
}
