# An aspect key `errors` gives error records, or plain messages. Nothing throws. `from` is always the giving scope.
{ yen, lib, ... }:
let
  hosts.instances = yen.kinds.host; # (1) a tree request: every host, with its data
in
{
  yen.aspects.unique-addr = {
    at = yen.kinds.fleet; # (2)
    cycle =
      { tree, ... }:
      {
        tree = [ hosts ];
        errors = [
          # (3)
          (lib.concatLists (
            lib.mapAttrsToList (
              a: hs:
              lib.optional (lib.length hs > 1) {
                code = "duplicate-addr"; # (4)
                error = "${a} is the address of ${lib.concatMapStringsSep " and " (h: h.name) hs}";
                fix = "give each host its own addr";
                path = [ "addr" ];
                got = a;
              }
            ) (lib.groupBy (h: h.addr) (lib.head (tree.select hosts)))
          ))
        ];
      };
  };
  yen.aspects.no-backup = {
    at = yen.lib.all [
      yen.kinds.host
      (s: !s.backup)
    ];
    warnings = { host, ... }: "${host.name} has no backup"; # (5)
  };
}
