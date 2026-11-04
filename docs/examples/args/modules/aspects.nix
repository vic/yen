{ yen, ... }:
{
  yen.aspects.backend = {
    at = yen.lib.all [
      yen.kinds.host
      (s: s.name != "lb")
    ];
    backends = { host, ... }: host.addr; # (1) a kind arg: the nearest host
  };
  yen.aspects.balancer = {
    at = yen.host.lb;
    proxy =
      {
        environment, # (2) a kind arg: the nearest environment
        backends, # (3) a sink arg: the reduced value at its nearest receiver (the environment)
        scope, # (4) the scope itself
        cluster ? null, # (5) optional: this fleet has no cluster
        ...
      }:
      {
        inherit backends;
        at = scope.id;
        env = environment.name;
        cluster = if cluster == null then "none" else cluster.name;
      };
  };
}
