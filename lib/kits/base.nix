#: lib.kits.base :: module -- bundle base: what a new machine needs (disk, hardware report, ssh, break-glass login) in one assembly
# One role, `default`. Interface: `device` (str), `layout` (one of `yen.kit.disko.layouts`), `authorizedKeys` (public keys), `hardware`
# (a path: the directory of `<machine>.json` nixos-facter reports). It adds one assembly each of disko, facter, sshd (a
# server on the same machines) and emergency-access. Users are left out: a user needs a name, and a name per machine
# would be a string. Import the four kits it adds (disko, facter, sshd, emergency-access) too.
#   imports = [ inputs.yen.lib.kits.base ];
_:
{ yen, lib, ... }:
let
  # the settings of a role at a machine: a role's settings may be a function of the machine
  settingsOf = r: m: if lib.isFunction (r.settings or { }) then r.settings m else r.settings or { };
  pick =
    names: a: m:
    lib.intersectAttrs (lib.genAttrs names (_: null)) (settingsOf a.roles.default m);
in
{
  yen.kit.base = {
    roles.default.interface = {
      device.type = yen.lib.str;
      layout.type = yen.kit.disko.roles.default.interface.layout.type; # a layout of kit disko
      authorizedKeys.type = yen.lib.listOf yen.lib.str;
      hardware.type = yen.lib.path;
    };
    # a kit that needs others: one assembly of each, on the machines of the base's role
    adds = a: {
      disko = {
        kit = yen.kit.disko;
        roles.default = {
          inherit (a.roles.default) at;
          settings = pick [ "device" "layout" ] a;
        };
      };
      facter = {
        kit = yen.kit.facter;
        roles.default = {
          inherit (a.roles.default) at;
          settings =
            m:
            lib.mapAttrs' (_: v: {
              name = "dir";
              value = v;
            }) (pick [ "hardware" ] a m);
        };
      };
      sshd = {
        kit = yen.kit.sshd;
        roles.server.at = a.roles.default.at;
      };
      emergency = {
        kit = yen.kit.emergency-access;
        roles.default = {
          inherit (a.roles.default) at;
          settings = pick [ "authorizedKeys" ] a;
        };
      };
    };
  };
}
