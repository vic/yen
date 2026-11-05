# A plausible edit: a new host `web`, copied from `api` and moved to `us`. It keeps the address of `api`, and its
# database is still in `eu`.
{ yen, ... }:
{
  yen.host.web = {
    addr = "10.0.0.1";
    region = yen.region.us;
    db = yen.host.db;
  };
}
