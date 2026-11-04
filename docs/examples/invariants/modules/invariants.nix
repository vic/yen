# Rules by reference: a rule is a function of its variables, and its literals come from `yen.facts`:
# `host.form H "server"` is "H is a host whose form is server". A rule with `bad = H` that holds is a violation.
{ yen, ... }:
let
  inherit (yen.facts) host has lt; # (1)
in
{
  # no server runs a desktop
  yen.invariants.no-desktop-on-servers =
    { H }: # (2)
    {
      bad = H; # (3)
      pos = [
        (host.form H "server") # (4)
        (has yen.aspects.desktop H) # (5)
      ];
    };

  # no two hosts share an address: a rule across machines (`lt` keeps one of each pair)
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
        (lt A B) # (6)
      ];
    };
}
