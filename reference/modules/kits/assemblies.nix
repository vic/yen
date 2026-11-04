# kits and assemblies in yen. A kit is data: roles, a typed interface per role, constraints, the export keys it may
# give, and the assemblies it adds. An assembly is one use of a kit: its `kit` is a ref, each role's machines an `at`
# predicate. Each machine spawns one `member` scope per (assembly, role) it takes, so an aspect at a member scope runs
# once per assembly and role, and an aspect at the machine above a member (`below`) runs once per machine.
# Exports are a fleet sink: the engine sets `from` (the member scope), so a kit cannot write another's scope.
# The rules are yen.lib.batteries.kits; this file is the fleet's data and its words.
{ yen, lib, ... }:
let
  inherit (yen.lib) opt holds;
  kits = yen.lib.batteries.kits;
  attrs = yen.lib.attrs;
  # the assemblies and the parts their kits add (a part lives under its assembly)
  withAdded = yen.lib.batteries.kits.assemblies;
  assemblies = withAdded (lib.attrValues yen.assembly); # spawns and helpers read data
  # tree requests: every assembly, host and mac, with their data
  own.instances = yen.kinds.assembly;
  hosts.instances = yen.kinds.host;
  macs.instances = yen.kinds.mac;
  membersOf = kits.members { inherit assemblies holds; };
in
{
  yen.kinds.kit.fields = {
    roles = opt attrs { };
    constraints = opt attrs { };
    exports = opt (yen.lib.listOf yen.lib.str) [ ];
    adds = opt (yen.lib.is lib.isFunction) (_: { });
  };
  yen.kinds.assembly.fields = {
    kit = yen.kinds.kit;
    roles = opt attrs { };
  };
  yen.helpers.assemblies = assemblies;
  yen.kinds.member = { }; # spawned under machines; its elements go up to the machine
  yen.kinds.host.spawns.member = membersOf;
  yen.kinds.mac.spawns.member = membersOf;

  # one fleet sink for exports; a reader keeps the elements of one assembly and role (`yen.lib.same`).
  # An element from the fleet scope is the owner's override of one element.
  yen.kinds.fleet.sinks.exports.reduce = kits.exports { isMember = holds yen.kinds.member; };

  # the contract: a kit ref, known roles, `at` predicates, machine and assembly counts; typed settings per member
  yen.aspects.kits-contract = {
    at = yen.kinds.fleet;
    cycle =
      { tree, ... }:
      {
        tree = [
          own
          hosts
          macs
        ];
        errors = [
          (kits.contract {
            assemblies = withAdded (tree.select own);
            machines = tree.select hosts ++ tree.select macs;
            inherit holds;
          })
        ];
      };
  };
  yen.aspects.kits-settings-typed = {
    at = yen.kinds.member;
    errors = kits.settings-typed;
  };
}
