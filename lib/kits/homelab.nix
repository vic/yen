#: lib.kits.homelab :: module -- bundle homelab: one server and nodes, with base, a wireguard network, backups, monitoring and dns
# Roles `server` (exactly 1) and `node`, both with the interface of base (`device`, `layout`, `authorizedKeys`,
# `hardware`) and `prefix` (the wireguard network); settings may be a function of the machine. It adds, from its own role
# `at`: base on both roles, wireguard (server controller, nodes peers), borg (server backs up, nodes are clients),
# monitoring (server scrapes, nodes export) and dns on the server. Each is a part of the homelab assembly; the parts
# of base and borg come with them (kits.assemblies). Import the kits it uses (base, disko, facter, sshd, emergency-access,
# wireguard, borg, monitoring, dns) as well; a machine needs the field `addr`.
#   imports = [ inputs.yen.lib.kits.homelab ];
_:
{ yen, lib, ... }:
let
  inherit (yen.lib) holds;
  iface = {
    prefix.type = yen.lib.str;
  }
  // yen.kit.base.roles.default.interface;
  # the settings of the role that holds the machine, restricted to names
  # the role that holds the machine, and its settings: a role's settings may be a function of the machine
  roleOf = a: m: if holds a.roles.server.at m then a.roles.server else a.roles.node;
  settingsOf = r: m: if lib.isFunction (r.settings or { }) then r.settings m else r.settings or { };
  of =
    a: names: m:
    lib.intersectAttrs (lib.genAttrs names (_: null)) (settingsOf (roleOf a m) m);
in
{
  yen.kit.homelab = {
    roles = lib.genAttrs [ "server" "node" ] (_: {
      interface = iface;
    });
    constraints.roles.server = {
      min = 1;
      max = 1;
    };
    adds = a: {
      base = {
        kit = yen.kit.base;
        roles.default = {
          at = [
            a.roles.server.at
            a.roles.node.at
          ];
          settings = of a [
            "device"
            "layout"
            "authorizedKeys"
            "hardware"
          ];
        };
      };
      wg = {
        kit = yen.kit.wireguard;
        roles = {
          controller = {
            inherit (a.roles.server) at;
            settings = of a [ "prefix" ];
          };
          peer = {
            inherit (a.roles.node) at;
            settings = of a [ "prefix" ];
          };
        };
      };
      monitoring = {
        kit = yen.kit.monitoring;
        roles = {
          server = { inherit (a.roles.server) at; };
          exporter = { inherit (a.roles.node) at; };
        };
      };
      dns = {
        kit = yen.kit.dns;
        roles.default = { inherit (a.roles.server) at; };
      };
      borg = {
        kit = yen.kit.borg;
        roles = {
          server = { inherit (a.roles.server) at; };
          client = { inherit (a.roles.node) at; };
        };
      };
    };
  };
}
