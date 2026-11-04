{ yen, ... }:
{
  yen.environment.prod.domain = "example.com";
  yen.environment.lab.domain = "lab.example.com";

  yen.host.web = {
    environment = yen.environment.prod; # (1)
    backup = yen.host.db; # (2)
  };
  yen.host.db = {
    environment = yen.environment.prod;
    backup = yen.host.web;
  }; # refs can point both ways
  yen.host.test.environment = yen.environment.lab;
}
