{ yen, lib, ... }:
let
  secrets.instances = yen.kinds.secret; # a tree request: every secret, with its data
in
{
  # each host gets the secrets that name it
  yen.aspects.deliver = {
    at = yen.kinds.host;
    cycle =
      { tree, scope, ... }:
      {
        tree = [ secrets ]; # (1)
        secrets = lib.filter (s: lib.any (yen.lib.same scope) s.owners) (lib.head (tree.select secrets)); # (2)
      };
  };
  # (3) a secret that no host owns is an error, not a silent leftover
  yen.aspects.orphans = {
    at = yen.kinds.fleet;
    cycle =
      { tree, ... }:
      {
        tree = [ secrets ];
        errors = [
          # (4)
          (map (s: "secret ${s.name} (${s.file}) has no owner") (
            lib.filter (s: s.owners == [ ]) (lib.head (tree.select secrets))
          ))
        ]; # one element: the list
      };
  };
}
