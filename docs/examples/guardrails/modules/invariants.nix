# Rules every change must keep, each one a mistake that fleets keep making. A rule with `bad = X` that holds is a violation.
{ yen, ... }:
let
  inherit (yen.facts)
    host
    service
    parent
    has
    lt
    ;
in
{
  # a copied address: a cloned machine comes up with the IP of its original
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

  # a port taken twice: the second service on a machine fails to start, or answers for the first
  yen.invariants.unique-port =
    {
      A,
      B,
      H,
      P,
    }:
    {
      bad = [
        A
        B
      ];
      pos = [
        (parent A H)
        (parent B H)
        (service.port A P)
        (service.port B P)
        (lt A B)
      ];
    };

  # a database on the internet
  yen.invariants.database-not-public =
    { S }:
    {
      bad = S;
      pos = [
        (service.reach S "internet")
        (has yen.aspects.database S)
      ];
    };

  # a database on a machine that is not backed up
  yen.invariants.database-has-backup =
    { S, H }:
    {
      bad = H;
      pos = [
        (parent S H)
        (has yen.aspects.database S)
        (host.backup H "none")
      ];
    };

  # production credentials on a machine of the dev zone
  yen.invariants.no-prod-credentials-in-dev =
    { H }:
    {
      bad = H;
      pos = [
        (host.zone H "dev")
        (has yen.aspects.prod-credentials H)
      ];
    };
}
