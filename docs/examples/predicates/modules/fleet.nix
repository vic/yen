# Hosts with facts, guests (VMs) under hosts. An `active` output lists each aspect's scopes.
{ yen, ... }:
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
  };
  yen.kinds.host = {
    fields = {
      cores = yen.lib.int;
      gpu = yen.lib.opt yen.lib.bool false;
    };
    spawns.guest = yen.lib.pointing "on" yen.guest; # (1)
  };
  yen.kinds.guest.fields.on = yen.kinds.host;

  yen.fleet.main = { };
  yen.host.big = {
    cores = 32;
    gpu = true;
  };
  yen.host.small.cores = 4;
  yen.guest.ci.on = yen.host.big;

}
