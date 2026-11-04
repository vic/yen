{ yen, ... }:
{
  yen.aspects.accounts = {
    at = [
      yen.kinds.user
      yen.kinds.home
    ];
    os = { scope, ... }: "account ${scope.name}"; # (1)
  };
  yen.aspects.records = {
    at = yen.kinds.host;
    dns = { host, ... }: "${host.name} A"; # (2)
  };
}
