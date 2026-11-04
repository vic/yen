# mesh: every host gives its key to the fleet; each host reads the keys of the others.
{ yen, ... }:
let
  inherit (yen.lib.batteries) mesh;
in
{
  yen.kinds.fleet.sinks.keys.reduce = yen.lib.reduce.elements; # (1) an element knows which host gave it
  yen.kinds.host.sinks.known = {
    reduce = yen.lib.reduce.one; # (2)
    out =
      { scope, sinks, ... }:
      {
        known.${scope.name} = sinks.known;
      };
  };

  yen.aspects.key = {
    at = yen.kinds.host;
    keys = { host, ... }: host.sshKey;
  };
  yen.aspects.known-hosts = {
    at = yen.kinds.host;
    known = mesh {
      # (3)
      from = yen.kinds.fleet.sinks.keys;
      build = keys: builtins.sort builtins.lessThan keys;
    };
  };
}
