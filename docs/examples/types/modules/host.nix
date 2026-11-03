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
    addr = yen.types.string; # required
    port = opt (yen.lib.is (v: builtins.isInt v && v >= 0 && v <= 65535)) 22; # a default
    jump = maybe yen.types.string; # null by default
    vpn = derive yen.types.string (self: "vpn-${self.name}"); # a default computed from the instance
    tags = opt (is (v: builtins.isList v && builtins.all builtins.isString v)) [ ]; # your own check
    labels = opt (yen.lib.attrsOf yen.types.string) { }; # an attrset whose values are strings
    settings.kernel.channel = opt (yen.lib.enum [
      "lts"
      "latest"
    ]) "lts"; # one of a list, and a nested field
  };
}
