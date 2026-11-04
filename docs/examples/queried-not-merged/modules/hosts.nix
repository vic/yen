{ yen, ... }:
{
  yen.kinds.host.fields.environment = yen.kinds.environment; # (1)
  yen.environment.prod.settings.zfs.arcMax = 8; # (2)

  yen.host.nas = {
    environment = yen.environment.prod;
    settings.zfs.arcMax = 32; # (3)
  };
  yen.host.node = {
    environment = yen.environment.prod;
    settings.k3s.role = "server";
  };
}
