{ yen, ... }:
{
  yen.host.web = { };
  yen.host.db = { };
  yen.secret.tls = {
    file = "secrets/tls.age";
    owners = [ yen.host.web ]; # (1)
  };
  yen.secret.db-password = {
    file = "secrets/db-password.age";
    owners = [
      # (2)
      yen.host.web
      yen.host.db
    ];
  };
}
