# The words of this fleet: machines with an address, a `nixos` sink, the kits' contract and exports.
{ yen, lib, ... }:
let
  kits = yen.lib.batteries.kits;
  inherit (yen.lib) opt holds;
  assemblies = lib.attrValues yen.assembly;
  # tree requests: every assembly and machine, with their data
  assemblyTree.instances = yen.kinds.assembly;
  machineTree.instances = yen.kinds.machine;
in
{
  yen.kinds.fleet = {
    spawns.machine = _: yen.machine;
    sinks.out.reduce = yen.lib.reduce.merge;
    sinks.exports = {
      reduce = kits.exports { isMember = holds yen.kinds.member; };
      out =
        { sinks, ... }:
        {
          exports = sinks.exports;
        };
    };
  };
  yen.kinds.machine = {
    fields.addr = yen.lib.is builtins.isString;
    spawns.member = kits.members { inherit assemblies holds; };
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
    roles = opt yen.lib.attrs { };
    constraints = opt yen.lib.attrs { };
    exports = opt (yen.lib.listOf yen.lib.str) [ ];
  };
  yen.kinds.assembly.fields = {
    kit = yen.kinds.kit;
    roles = opt yen.lib.attrs { };
  };
  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
  # the fleet is read through tree requests, never as refs: an aspect reads instance data only through args
  yen.aspects.contract = {
    at = yen.kinds.fleet;
    cycle =
      { tree, ... }:
      {
        tree = [
          assemblyTree
          machineTree
        ];
        errors = [
          (kits.contract {
            assemblies = tree.select assemblyTree;
            machines = tree.select machineTree;
            inherit holds;
          })
        ];
      };
  };
  yen.aspects.settings-typed = {
    at = yen.kinds.member;
    errors = kits.settings-typed;
  };
}
