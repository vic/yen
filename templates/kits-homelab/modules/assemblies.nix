# A bundle is a kit whose assemblies make more assemblies: one `homelab` assembly names the server and the nodes,
# and the base, wireguard, borg, monitoring and dns assemblies follow from those two roles. Import the kits it uses.
{ yen, inputs, ... }:
let
  inherit (yen) host kit;
  k = inputs.yen.lib.kits;
  # the settings every role of a homelab needs; the variants reuse them so only the contract differs
  shared = {
    device = "/dev/sda";
    layout = yen.layout.single-ext4;
    authorizedKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAdminKeyNotReal admin" ];
    hardware = ../hardware; # placeholder: create this directory for your hardware
    prefix = "10.8.0.0/24";
  };
in
{
  imports = [
    k.homelab
    k.base
    k.disko
    k.facter
    k.sshd
    k.emergency-access
    (k.wireguard { root = ../vars; })
    k.borg
    k.monitoring
    k.dns
  ];
  yen.host = {
    lb.addr = "10.0.0.1";
    web.addr = "10.0.0.2";
    nas.addr = "10.0.0.3";
  };
  yen.assembly.lab = {
    kit = kit.homelab;
    roles = {
      server = {
        at = host.nas;
        settings = shared // {
          device = "/dev/sda /dev/sdb";
          layout = yen.layout.zfs-mirror;
        };
      };
      node = {
        at = [
          host.lb
          host.web
        ];
        settings = shared;
      };
    };
  };
}
