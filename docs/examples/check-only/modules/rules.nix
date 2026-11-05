# Two rules across machines. Each one is a mistake that no single host can see on its own.
{ yen, ... }:
let
  inherit (yen.facts) host lt;
in
{
  # no two hosts share an address (`lt` keeps one of each pair)
  yen.invariants.unique-addr =
    {
      A,
      B,
      X,
    }:
    {
      bad = [
        A
        B
      ];
      pos = [
        (host.addr A X)
        (host.addr B X)
        (lt A B)
      ];
    };

  # a host and its database live in the same region
  yen.invariants.db-same-region =
    {
      H,
      D,
      R,
    }:
    {
      bad = H;
      pos = [
        (host.db H D)
        (host.region H R)
      ];
      neg = [ (host.region D R) ];
    };
}
