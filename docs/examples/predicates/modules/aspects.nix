{ yen, ... }:
let
  inherit (yen.lib)
    all
    not
    within
    below
    ;
in
{
  yen.aspects = {
    builder.at = s: (s.cores or 0) >= 16; # (1) a function of the scope: a fact test
    cuda.at = all [
      yen.kinds.host
      (s: s.gpu)
    ]; # (2) all of a list
    tiny.at = all [
      yen.kinds.host
      (not yen.aspects.builder)
    ]; # (3) an aspect ref, negated
    vm-tools.at = within yen.aspects.cuda; # (4) a proper ancestor holds
    vm-host.at = below yen.kinds.guest; # (5) a child holds
    monitored.at = [
      yen.host.small
      yen.aspects.vm-host
    ]; # (6) a list is "any"
  };
}
