# An explicit `spawns.user` replaces the default. This host spawns only the user `vic`.
{ yen, ... }:
{
  yen.kinds.host.spawns.user = s: { inherit (s.user) vic; };
}
