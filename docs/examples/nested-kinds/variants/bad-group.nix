# The users of a host are an attrset of instances. A string is not.
{ yen, ... }:
{
  yen.host.desk = {
    addr = "10.0.0.3";
    user = "vic";
  };
}
