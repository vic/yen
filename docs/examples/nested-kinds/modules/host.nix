# A kind declared inside a kind. `user` exists only under `host`: there is no `yen.kinds.user`.
{ yen, lib, ... }:
{
  yen.kinds.host = {
    fields.addr = lib.types.str;
    kinds.user.fields.shell = lib.types.str;
  };
}
