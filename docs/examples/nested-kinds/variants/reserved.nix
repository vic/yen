# A field named like a nested kind shares its path in the instance.
{ yen, lib, ... }:
{
  yen.kinds.host.fields.user = yen.lib.str;
}
