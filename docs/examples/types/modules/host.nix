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
    addr = yen.lib.str; # required
    port = opt yen.lib.port 22; # a default
    jump = maybe yen.lib.str; # null by default
    vpn = derive yen.lib.str (self: "vpn-${self.name}"); # a default computed from the instance
    tags = opt (is (v: builtins.isList v && builtins.all builtins.isString v)) [ ]; # your own check
    labels = opt (yen.lib.attrsOf yen.lib.str) { }; # an attrset whose values are strings
    settings.kernel.channel = opt (yen.lib.enum [
      "lts"
      "latest"
    ]) "lts"; # one of a list, and a nested field
  };
}
