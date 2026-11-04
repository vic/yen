# Four assemblies: db serves ssh and trusts nothing, web trusts db, ops logs in on web, a break-glass key on db.
{ yen, ... }:
{
  yen.assembly = {
    ssh = {
      kit = yen.kit.sshd; # (1)
      roles = {
        server.at = yen.machine.db; # (2)
        client = {
          at = yen.machine.web;
          settings.root = ../vars/per-machine; # (3) where the public host keys are read from
        };
      };
    };
    ops = {
      kit = yen.kit.users;
      roles.default = {
        at = yen.machine.web;
        settings = {
          # (4)
          user = "ops";
          groups = [ "wheel" ];
        };
      };
    };
    break-glass = {
      kit = yen.kit.emergency-access;
      roles.default = {
        at = yen.machine.db;
        settings.authorizedKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBreakGlassKeyNotReal admin" ]; # (5)
      };
    };
  };
}
