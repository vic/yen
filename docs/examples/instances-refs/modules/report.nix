{ yen, lib, ... }:
let
  hosts.instances = yen.kinds.host; # a tree request: every host, with its data
  # the other hosts of the host's environment; `same` compares two instances by kind and name
  peersOf =
    tree: host:
    lib.filter (h: !yen.lib.same h host && yen.lib.same h.environment host.environment) (
      lib.head (tree.select hosts)
    );
in
{
  yen.aspects.report = {
    at = yen.kinds.host;
    cycle =
      { tree, scope, ... }:
      {
        tree = [ hosts ];
        report = [
          {
            ${scope.name} = {
              fqdn = "${scope.name}.${scope.environment.domain}"; # follow a ref, read its fields
              backup = if scope.backup == null then null else scope.backup.name;
              peers = map (h: h.name) (peersOf tree scope);
            };
          }
        ];
      };
  };
}
