# An aspect reads the fields of the nearest host.
{ yen, ... }:
{
  yen.aspects.report = {
    at = yen.kinds.host; # (1)
    report =
      { host, ... }: # (2)
      {
        ${host.name} = "${host.addr} (${toString host.cores} cores)"; # (3)
      };
  };
}
