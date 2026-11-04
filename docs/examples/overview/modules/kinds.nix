# Kinds: typed data. `office` is the root: nothing spawns it.
{ yen, lib, ... }:
{
  yen.kinds.office = {
    spawns.machine = _: yen.machine; # (1)
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.machine = {
    fields.owner = yen.lib.str; # (2)
    sinks.packages.reduce = yen.lib.reduce.set; # (3)
    sinks.packages.out =
      { machine, packages, ... }: # (4)
      {
        inventory.${machine.name} = packages;
      };
  };

  yen.office.main = { }; # (5)
  yen.machine.reception.owner = "ana";
  yen.machine.studio.owner = "bo";
  yen.flake = { out, ... }: out;
}
