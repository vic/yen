{ yen, ... }:
{
  yen.host.nas.addr = "10.0.0.10";
  yen.host.web.addr = "10.0.0.1";
  yen.host.db.addr = "10.0.0.2";
  yen.assembly.backup.roles = {
    # (1)
    server = [ yen.host.nas ]; # (2)
    client = [
      yen.host.web
      yen.host.db
    ];
  };
}
