# Instances: `yen.<kind>.<name>`. The name is the attribute name.
{ yen, ... }:
{
  yen.host.web = {
    addr = "10.0.0.1"; # (1)
    cores = 4; # (2)
  };
  yen.host.db = {
    addr = "10.0.0.2";
    cores = 16;
  };
}
