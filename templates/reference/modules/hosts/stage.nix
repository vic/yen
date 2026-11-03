{ yen, ... }:
{
  yen.host.stage = {
    environment = yen.environment.staging;
    channel = yen.channel.unstable;
    system = yen.system.x86_64-linux;
    addr = "10.0.2.10";
  };
}
