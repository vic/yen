# Each line breaks one sink rule.
{ yen, ... }:
{
  yen.aspects.mistakes = {
    at = yen.host.web;
    admin = "bob"; # (1) `one`: two admins
    ports = 70000; # (2) `of`: not a port
    nginx.http.gzip = false; # (3) `merge`: two different leaves at one path
  };
}
