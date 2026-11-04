# the addresses and the error records of one wireguard assembly (kit wireguard): `es` are the reduced exports of the
# assembly; `pk` reads a public key or null. `check` lists address errors, members that disagree on the prefix and
# members whose public key file is missing.
_:
{
  yen,
  lib,
  pk,
}:
let
  b = builtins;
  alloc =
    es:
    yen.lib.batteries.addresses {
      prefix = (b.head es).value.prefix; # the same in every member: a difference is an error (check)
      members = map (name: { inherit name; }) (lib.unique (map (x: x.machine.name) es));
    };
  # p: the first member; every member must have its prefix
  differ = p: b.any (x: x.value.prefix != p.value.prefix);
in
{
  inherit alloc;
  check =
    es:
    (alloc es).errors
    ++ (
      if differ (b.head es) es then
        [ { error = "wireguard: assembly ${(b.head es).assembly.name} members disagree on prefix"; } ]
      else
        [ ]
    )
    ++ map (x: { error = "wireguard: ${x.machine.name} has no ${x.value.public} public key"; }) (
      b.filter (x: pk x == null) es
    );
}
