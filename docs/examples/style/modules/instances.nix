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
      env = yen.env.prod; # (1) a ref: the value is the instance, not a string
      ports = [ 443 ];
    };
    db = {
      env = yen.env.prod;
      ports = [ 5432 ];
    };
    box.env = yen.env.lab;
  };
  yen.user.ana.hosts = [
    # (2)
    yen.host.web
    yen.host.box
  ];
  yen.flake = { out, ... }: out;
}
