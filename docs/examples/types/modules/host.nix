# A type is anything with `check = value: bool`. yen adds defaults on top of it.
{ yen, lib, ... }:
let
  inherit (yen.lib)
    opt
    maybe
    derive
    is
    ;
in
{
  yen.kinds.host.fields = {
    addr = yen.lib.str; # (1) required
    port = opt yen.lib.port 22; # (2) a default
    jump = maybe yen.lib.str; # (3) null by default
    vpn = derive yen.lib.str (self: "vpn-${self.name}"); # (4) a default computed from the instance
    tags = opt (is (v: builtins.isList v && builtins.all builtins.isString v)) [ ]; # (5) your own check
    labels = opt (yen.lib.attrsOf yen.lib.str) { }; # (6) an attrset whose values are strings
    settings.kernel.channel = opt (yen.lib.enum [
      "lts"
      "latest"
    ]) "lts"; # (7) one of a list, and a nested field
  };
}
