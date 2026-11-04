# Aspects: behavior, active where `at` holds. Each key gives one element to the sink of that name.
{ yen, ... }:
{
  yen.aspects.basics = {
    at = yen.kinds.machine; # (1)
    packages = "git";
  };
  yen.aspects.design = {
    at = yen.machine.studio; # (2)
    packages = "gimp";
  };
  yen.aspects.versioned-assets = {
    at = yen.aspects.design; # (3)
    packages = "git"; # (4)
  };
}
