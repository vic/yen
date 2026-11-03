# NixOS `options` become kind fields. A field type is anything with `check`: here nixpkgs types and yen.lib.is.
{ yen, ... }:
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
  };
  yen.kinds.host = {
    fields = {
      addr = yen.lib.str;
      firewall.enable = yen.lib.opt yen.lib.bool false; # mkEnableOption: a nested field with a default
      firewall.ports = yen.lib.opt (yen.lib.listOf yen.lib.port) [ ]; # checks every item
    };
    spawns.user = yen.lib.pointing "on" yen.user;
    sinks.nixos.reduce = yen.lib.reduce.merge;
  };
  # attrsOf (submodule { … }) in NixOS: here a kind, whose instances have names, refs and their own errors
  yen.kinds.user.fields = {
    on = yen.kinds.host;
    shell = yen.lib.opt yen.lib.str "bash";
  };
}
