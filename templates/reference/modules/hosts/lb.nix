{ yen, ... }:
{
  yen.host.lb = {
    environment = yen.environment.prod;
    channel = yen.channel.unstable;
    system = yen.system.x86_64-linux;
    addr = "10.0.1.1";
    sharedPkgs = true;
  };
}
