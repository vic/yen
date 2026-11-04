# Assemblies of the library kits. `layout` is a ref to a layout, never a string; `dir` holds one facter report per machine.
{ yen, lib, ... }:
{
  yen.kinds.member = { };
  yen.kinds.kit.fields = {
    roles = yen.lib.opt yen.lib.attrs { };
    constraints = yen.lib.opt yen.lib.attrs { };
  };
  yen.kinds.assembly.fields = {
    kit = yen.kinds.kit;
    roles = yen.lib.opt yen.lib.attrs { };
  };
  yen.aspects.settings-typed = {
    at = yen.kinds.member;
    errors = yen.lib.batteries.kits.settings-typed; # (1)
  };

  yen.assembly = {
    disk-lb = {
      kit = yen.kit.disko;
      roles.default = {
        at = yen.host.lb;
        settings = {
          device = "/dev/sda";
          layout = yen.kit.disko.layouts.single-ext4; # (2)
        };
      };
    };
    disk-web = {
      kit = yen.kit.disko;
      roles.default = {
        at = yen.host.web;
        settings = {
          device = "/dev/nvme0n1";
          layout = yen.kit.disko.layouts.btrfs-luks;
        };
      };
    };
    disk-nas = {
      kit = yen.kit.disko;
      roles.default = {
        at = yen.host.nas;
        settings = {
          device = "/dev/sda /dev/sdb";
          layout = yen.kit.disko.layouts.zfs-mirror;
        };
      };
    };
    hardware = {
      kit = yen.kit.facter;
      roles.default = {
        at = yen.host.lb;
        settings.dir = ../hardware; # (3)
      };
    };
  };
}
