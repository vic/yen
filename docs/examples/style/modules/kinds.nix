# The words of this fleet. A child names its parent in a ref field, and `pointing` spawns it.
{ yen, ... }:
{
  yen.kinds.fleet = {
    spawns.env = _: yen.env;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.env.spawns.host = yen.lib.pointing "env" yen.host; # (1)
  yen.kinds.host = {
    fields = {
      env = yen.kinds.env; # (2)
      ports = yen.lib.opt (yen.lib.listOf yen.lib.port) [ ]; # (3)
    };
    spawns.user = yen.lib.pointing "hosts" yen.user;
    sinks.nixos = {
      reduce = yen.lib.reduce.merge;
      out =
        { scope, sinks, ... }:
        {
          config.${scope.name} = sinks.nixos;
        };
    };
  };
  yen.kinds.user.fields.hosts = yen.lib.listOf yen.kinds.host;
}
