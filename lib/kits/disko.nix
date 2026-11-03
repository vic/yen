#: lib.kits.disko :: module -- kit disko: a machine's disks from a named layout of the kit
# The kit owns its layouts: `yen.kit.disko.layouts.<name>`, each `{ devices = device: disko devices; }`. They are values
# of the kit, not a kind: the kit adds no name outside itself. Its member gives the devices to sink `disks` of the
# machine kind, which the fleet declares (merge). The setting `layout` is one of the kit's layouts.
#   imports = [ inputs.yen.lib.kits.disko ];
#   roles.default.settings.layout = yen.kit.disko.layouts.single-ext4;
self:
{ yen, lib, ... }:
let
  # a layout: a record whose `devices` makes disko devices from a device string
  layout = {
    check = v: builtins.isAttrs v && builtins.isFunction (v.devices or null);
    description = "a layout of kit disko (yen.kit.disko.layouts.<name>)";
  };
in
{
  yen.kinds.kit.fields.layouts = yen.lib.opt (yen.lib.attrsOf layout) { };
  yen.kit.disko = {
    layouts = self._layouts { inherit lib; };
    roles.default.interface = {
      device.type = yen.lib.str;
      layout.type = layout;
    };
  };
  yen.kit.disko.aspects.default = {
    at = yen.lib.all [
      yen.kinds.member
      (s: yen.lib.same (s.kit or null) yen.kit.disko)
    ];
    # a setting that is no layout is the error settings-typed gives; here it gives no disks ({ })
    disks =
      { member, ... }:
      let
        s = member.settings;
      in
      if s.layout ? devices then s.layout.devices s.device else { };
  };
}
