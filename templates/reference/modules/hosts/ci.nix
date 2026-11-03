# ci is a guest on stage: both on the unstable channel.
{ yen, ... }:
{
  yen.guest.ci = {
    environment = yen.environment.staging;
    channel = yen.channel.unstable;
    system = yen.system.x86_64-linux;
    addr = "10.0.2.20";
    on = yen.host.stage;
  };
}
