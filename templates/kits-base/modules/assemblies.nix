# One `base` assembly gives every machine a disk layout, its hardware report, an ssh server and a break-glass login.
# The bundle adds a disko, facter, sshd and emergency-access assembly; import those kits too.
{ yen, inputs, ... }:
let
  inherit (yen) host kit;
  k = inputs.yen.lib.kits;
in
{
  imports = [
    k.base
    k.disko
    k.facter
    k.sshd
    k.emergency-access
  ];
  yen.host = {
    web.addr = "10.0.0.2";
    db.addr = "10.0.0.3";
  };
  yen.assembly.machines = {
    kit = kit.base;
    roles.default = {
      at = [
        host.web
        host.db
      ];
      settings = {
        device = "/dev/sda";
        layout = yen.kit.disko.layouts.single-ext4;
        authorizedKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAdminKeyNotReal admin" ];
        hardware = ../hardware; # placeholder: create this directory for your hardware; nixos-facter reports, <machine>.json; the install app writes them
      };
    };
  };
}
