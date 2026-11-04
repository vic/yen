# A kind is a type too: a field of kind `environment` holds a ref to an environment instance.
# Nothing spawns `environment`, so it is a data kind: its instances have no scope.
{ yen, lib, ... }:
{
  yen.kinds.environment.fields.domain = yen.lib.str; # (1)
  yen.kinds.host.fields = {
    environment = yen.kinds.environment; # (2)
    backup = yen.lib.maybe yen.kinds.host; # (3) a ref to another host, or null
  };
}
