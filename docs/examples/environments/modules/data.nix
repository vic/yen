{ yen, ... }:
{
  yen.group = {
    admins = { };
    devs = { };
  };
  yen.environment.prod = {
    domain = "example.com";
    grants = [ yen.group.admins ]; # (1)
    settings.timeZone = "UTC";
  };
  yen.environment.staging = {
    domain = "staging.example.com";
    base = yen.environment.prod; # (2)
    grants = [
      yen.group.admins
      yen.group.devs
    ];
  };
  yen.host.web = {
    environment = yen.environment.prod;
  };
  yen.host.web-next = {
    environment = yen.environment.staging;
    settings.timeZone = "Europe/Berlin"; # (3)
  };
  yen.host.api-next = {
    environment = yen.environment.staging;
  };
  yen.user.ana.groups = [ yen.group.admins ];
  yen.user.dev.groups = [ yen.group.devs ];
}
