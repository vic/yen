#: lib.kits.zerotier :: { root; } -> module -- a zerotier network: one controller, up to four moons, peers; identities from generators
# `root`: where public values are read from. The controller gives the network id, a moon its moon id (public files); the
# identities are secret files linked by path, never in the store. A member reads the exports of its own assembly.
# shortcut: moons are listed in /etc/zerotier/moons, add orbit when NixOS has an option for it
#   imports = [ (inputs.yen.lib.kits.zerotier { root = ../../vars/per-machine; }) ];
_:
{ root }:
{ yen, lib, ... }:
let
  inherit (yen.lib) all same;
  pub = yen.lib.batteries.vars.public-value { inherit root; };
  members = all [
    yen.kinds.member
    (s: same (s.kit or null) yen.kit.zerotier)
  ];
  pk = x: pub x.machine.name "from-exports" x.value.public null; # null: the public file is missing
  # the generator file stem of a member: one per assembly for the controller, one per machine for a moon
  stem =
    role: a: m:
    if role == "controller" then "zt-${a.name}" else "zt-${a.name}-${m}";
  # the file a controller (`nwid`) or a moon (`moon`) publishes
  fileOf = role: if role == "controller" then "nwid" else "moon";
  # a controller's or a moon's identity: a generator on its machine, and the public file it exports
  idsOf = k: id: machine: {
    public = "${k}.${id}";
    generators.${k} = {
      deploy = [ machine ];
      files."${k}.identity".secret = true;
      files."${k}.${id}".secret = false;
    };
  };
  # the public values of one role in a member's assembly: network ids or moon ids
  publicOf =
    member: exports: role:
    lib.filter (v: v != null) (
      map pk (
        lib.filter (x: same x.assembly member.assembly && x ? value.public && x.role == role) exports
      )
    );
in
{
  yen.kit.zerotier = {
    roles = {
      controller = { };
      moon = { };
      peer = { };
    };
    constraints.roles = {
      controller = {
        min = 1;
        max = 1;
      };
      moon.max = 4;
    };
    exports = [
      "public"
      "generators"
    ];
  };
  yen.kit.zerotier.aspects.ids = {
    at = members;
    exports =
      { member, scope, ... }:
      lib.optionalAttrs (member.role != "peer") (
        idsOf (stem member.role member.assembly scope.parent.name) (fileOf member.role) scope.parent
      );
  };
  yen.kit.zerotier.aspects.check = {
    at = yen.kinds.fleet;
    errors =
      { exports, ... }:
      map (x: "zerotier: ${x.machine.name} has no ${x.value.public} public file") (
        lib.filter (x: same x.kit yen.kit.zerotier && x ? value.public && pk x == null) exports
      );
  };
  yen.kit.zerotier.aspects.net = {
    at = members;
    nixos =
      {
        member,
        scope,
        exports,
        ...
      }:
      {
        services.zerotierone = {
          enable = true;
          joinNetworks = publicOf member exports "controller";
        };
        environment.etc."zerotier/moons".text = lib.concatStringsSep "\n" (publicOf member exports "moon");
      }
      // lib.optionalAttrs (member.role != "peer") {
        systemd.tmpfiles.rules = [
          "L+ /var/lib/zerotier-one/identity.secret - - - - /run/secrets/vars/from-exports/${
            stem member.role member.assembly scope.parent.name
          }.identity"
        ];
      };
  };
}
