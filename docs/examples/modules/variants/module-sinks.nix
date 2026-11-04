# NixOS top-level `options` become module sinks. `yen.sinks` declares one: `of` checks each module's value,
# `reduce` merges the values. Any module reads the sink as an arg.
{ yen, ... }:
{
  yen.sinks.admins = {
    # (1)
    of = yen.lib.listOf yen.lib.str; # (2)
    reduce = yen.lib.reduce.flat; # (3)
  };
  imports = [
    # (4)
    { admins = [ "ana" ]; } # (5)
    { admins = [ "bo" ]; }
    (
      { yen, admins, ... }: # (6)
      {
        yen.aspects.wheel = {
          at = yen.host.web;
          nixos.users.groups.wheel.members = admins;
        };
      }
    )
  ];
}
