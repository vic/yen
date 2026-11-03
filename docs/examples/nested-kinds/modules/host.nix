# A kind declared inside a kind. `user` exists only under `host`: there is no `yen.kinds.user`.
{ yen, lib, ... }:
{
  yen.kinds.host = {
    fields.addr = yen.lib.str;
    kinds.user.fields.shell = yen.lib.str;
  };
}
