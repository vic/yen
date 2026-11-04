# The ref of a nested kind is the path of its declaration: `yen.kinds.host.kinds.user`.
{ yen, ... }:
{
  yen.aspects.report = {
    at = yen.kinds.host.kinds.user; # (1)
    report = { scope, ... }: "${scope.id} ${scope.shell}"; # (2)
  };
}
