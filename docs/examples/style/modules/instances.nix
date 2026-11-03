# The data: refs, never names.
{ yen, ... }:
{
  yen.fleet.main = { };
  yen.env = {
    prod = { };
    lab = { };
  };
  yen.host = {
    web = {
      env = yen.env.prod;
      ports = [ 443 ];
    };
    db = {
      env = yen.env.prod;
      ports = [ 5432 ];
    };
    box.env = yen.env.lab;
  };
  yen.user.ana.hosts = [
    yen.host.web
    yen.host.box
  ];
  yen.flake = { out, ... }: out;
}
