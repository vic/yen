{ yen, ... }:
{
  yen.aspects.base = {
    at = yen.kinds.host;
    motd = "welcome"; # (1)
    ports = 22; # (2)
    packages = [
      "git"
      "curl"
    ]; # (3) `flat` joins list elements
    admin = "alice";
    nginx.http.gzip = true;
    owners = "ops";
    groups = "wheel";
  };
  yen.aspects.web = {
    at = yen.host.web;
    motd = "this host serves web";
    ports = 22; # (4) a duplicate: `set` keeps one
    packages = [
      "nginx"
      "git"
    ]; # (5) a duplicate: `flat` keeps one, in order of arrival
    nginx.http.servers.www.port = 80; # `merge` joins the attrsets
    groups = "audio";
  };
}
