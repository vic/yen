# NixOS `options` become kind fields. A field type is anything with `check`: here nixpkgs types and yen.lib.is.
{ yen, ... }:
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
  };
  yen.kinds.host = {
    fields = {
      addr = yen.lib.str; # (1)
      firewall.enable = yen.lib.opt yen.lib.bool false; # (2) mkEnableOption: a nested field with a default
      firewall.ports = yen.lib.opt (yen.lib.listOf yen.lib.port) [ ]; # (3) checks every item
    };
    spawns.user = yen.lib.pointing "on" yen.user; # (4)
    sinks.nixos.reduce = yen.lib.reduce.merge; # (5)
  };
  # attrsOf (submodule { … }) in NixOS: here a kind, whose instances have names, refs and their own errors
  yen.kinds.user.fields = {
    on = yen.kinds.host; # (6)
    shell = yen.lib.opt yen.lib.str "bash";
  };
}
