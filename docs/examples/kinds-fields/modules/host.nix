# A kind declares the fields of its instances. Every field has a type.
{ yen, lib, ... }:
{
  yen.kinds.host.fields = {
    addr = yen.lib.str; # (1)
    cores = yen.lib.int; # (2)
  };
}
