#: lib.kits.wifi :: module -- wifi kit: one role with `networks`; every network gets its own PSK generator
# Generator `wifi.<assembly>.<network>` is shared (all machines of the role get the same PSK) and has one secret
# file `psk`. The network list lands in /etc/wifi/networks; the PSK files are deployed by the vars plan.
#   imports = [ inputs.yen.lib.kits.wifi ];
_:
{ yen, lib, ... }:
let
  inherit (yen.lib) all same;
  at = all [
    yen.kinds.member
    (s: same (s.kit or null) yen.kit.wifi)
  ];
in
{
  yen.kit.wifi.roles.default.interface.networks = {
    type = yen.lib.attrs;
    default = { };
  };
  yen.kit.wifi.aspects.default = {
    inherit at;
    nixos =
      { member, ... }:
      {
        environment.etc."wifi/networks".text = toString (lib.attrNames member.settings.networks);
      };
  };
  yen.kit.wifi.aspects.psk = {
    inherit at;
    generators =
      { member, ... }:
      map (n: {
        name = "wifi.${member.assembly.name}.${n}";
        share = true;
        files.psk.secret = true;
      }) (lib.attrNames member.settings.networks);
    # a dot in a name would let two networks share one generator: assembly a.b with network c is a with b.c
    errors =
      { member, ... }:
      map (n: "wifi: ${n} has a dot; assembly and network names must have none") (
        lib.filter (lib.hasInfix ".") ([ member.assembly.name ] ++ lib.attrNames member.settings.networks)
      );
  };
}
