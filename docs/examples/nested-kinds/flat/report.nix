{ yen, ... }:
{
  yen.aspects.report = {
    at = yen.kinds.user;
    report = { scope, ... }: "${scope.id} ${scope.shell}";
  };
}
