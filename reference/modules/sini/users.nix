# homeLinux: a user sink that only users on linux machines have. Primary user: a user element that goes up to the host.
{ yen, lib, ... }:
let
  inherit (yen.helpers) linux upTo;
  # the user owns the linux machine it lives on
  ownsMachine =
    s: (upTo linux s).system-owner or null != null && yen.lib.same (upTo linux s).system-owner s;
in
{
  yen.kinds.user.sinks.homeLinux = {
    at = s: lib.hasSuffix "-linux" ((upTo linux s).system.name or "");
    homeManager =
      { homeLinux, ... }:
      {
        imports = homeLinux;
      };
  };
  yen.aspects.linux-home = {
    at = yen.kinds.user;
    homeLinux.home.sessionVariables.YEN_LINUX = "1";
  };
  yen.kinds.machine.fields.system-owner = yen.lib.maybe yen.kinds.user;
  yen.host.lb.system-owner = yen.user.alice;
  yen.aspects.primary-user = {
    at = yen.lib.all [
      yen.kinds.user
      ownsMachine
    ];
    nixos =
      { user, ... }:
      {
        nix.settings.trusted-users = [ user.name ];
      };
  };
}
