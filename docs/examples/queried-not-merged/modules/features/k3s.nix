{ yen, lib, ... }:
{
  yen.kinds.host.fields.settings.k3s.role = yen.lib.opt yen.lib.str "agent";
}
