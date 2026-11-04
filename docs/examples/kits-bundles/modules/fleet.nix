# The fleet's words: hosts with an address, members of assemblies, and the sinks the library kits write to.
{ yen, lib, ... }:
let
  kits = yen.lib.batteries.kits;
  inherit (yen.lib) opt holds;
  attrs = yen.lib.attrs;
  # the fleet's assemblies and the parts their kits add (a part lives under its assembly)
  assemblies = yen.lib.batteries.kits.assemblies (lib.attrValues yen.assembly); # (1)
  # tree requests: every assembly and host, with their data
  assemblyTree.instances = yen.kinds.assembly;
  hostTree.instances = yen.kinds.host;
  machineOf = s: if holds yen.kinds.member s then s.parent else s;
in
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks = {
      out.reduce = yen.lib.reduce.merge;
      exports.reduce = kits.exports { isMember = holds yen.kinds.member; };
      generators = {
        reduce = yen.lib.batteries.vars.generators { inherit machineOf; };
        out = yen.lib.batteries.vars.vars-plan {
          from = yen.kinds.fleet.sinks.generators;
          machines = lib.attrNames yen.host;
          recipientsOf = _: [ "age1admin" ];
        };
      };
    };
  };
  yen.kinds.host = {
    fields.addr = yen.lib.str;
    spawns.member = kits.members { inherit assemblies holds; }; # (2)
    # the NixOS keys of a host, as data
    sinks.disks.reduce = yen.lib.reduce.merge; # kit disko gives disks here
    # (3) a kit's `os` keys (sshd's server) are the host's NixOS; without this sink they are dropped
    sinks.os.nixos =
      { os, ... }:
      {
        imports = os;
      };
    sinks.nixos = {
      reduce = yen.lib.reduce.merge;
      out =
        { scope, sinks, ... }:
        {
          config.${scope.name} = sinks.nixos;
        };
    };
  };
  yen.kinds.member = { };
  yen.kinds.kit.fields = {
    roles = opt attrs { };
    constraints = opt attrs { };
    exports = opt (yen.lib.listOf yen.lib.str) [ ];
    adds = opt (yen.lib.is builtins.isFunction) (_: { });
  };
  yen.kinds.assembly.fields = {
    kit = yen.kinds.kit;
    roles = opt attrs { };
  };
  # the fleet is read through tree requests, never as refs: an aspect reads instance data only through args
  yen.aspects.contract = {
    at = yen.kinds.fleet;
    cycle =
      { tree, ... }:
      {
        tree = [
          assemblyTree
          hostTree
        ];
        errors = [
          (kits.contract {
            # (4)
            assemblies = yen.lib.batteries.kits.assemblies (tree.select assemblyTree);
            machines = tree.select hostTree;
            inherit holds;
          })
        ];
      };
  };
  yen.aspects.settings-typed = {
    at = yen.kinds.member;
    errors = kits.settings-typed; # (5)
  };
  # a generator that an export carries goes to the machines of its `deploy` predicate
  yen.aspects.generators-from-exports = {
    at = yen.kinds.host;
    generators = yen.lib.batteries.vars.from-exports { inherit holds; }; # (6)
  };
  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
}
