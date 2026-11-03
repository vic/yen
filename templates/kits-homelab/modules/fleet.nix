# The fleet's words: hosts with an address, members of assemblies, and the sinks the library kits write to.
# Each host's NixOS keys become `nixosConfigurations.<host>`.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  kits = yen.lib.batteries.kits;
  inherit (yen.lib) opt holds;
  attrs = yen.lib.attrs;
  # the fleet's assemblies and the parts their kits add (a part lives under its assembly)
  assemblies = yen.lib.batteries.kits.assemblies (lib.attrValues yen.assembly);
  # tree requests: every assembly and host, with their data
  assemblyTree.instances = yen.kinds.assembly;
  hostTree.instances = yen.kinds.host;
  machineOf = s: if holds yen.kinds.member s then s.parent else s;
  get = tree: q: lib.head (tree.select q);
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
    spawns.member = kits.members { inherit assemblies holds; };
    # the NixOS keys of a host, as data
    sinks.disks.reduce = yen.lib.reduce.merge; # kit disko gives disks here
    # a kit's `os` keys (sshd's server) are the host's NixOS
    sinks.os.nixos =
      { os, ... }:
      {
        imports = os;
      };
    sinks.nixos = {
      reduce = yen.lib.reduce.merge;
      out = yen.lib.batteries.configurations {
        from = yen.kinds.host.sinks.nixos;
        output = "nixosConfigurations";
        build =
          _: keys:
          inputs.nixpkgs.lib.nixosSystem {
            modules = [
              keys
              inputs.disko.nixosModules.disko
              {
                nixpkgs.hostPlatform = "x86_64-linux";
                system.stateVersion = "25.05";
              }
            ];
          };
      };
    };
  };
  yen.kinds.member = { };
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
            assemblies = yen.lib.batteries.kits.assemblies (get tree assemblyTree);
            machines = get tree hostTree;
            inherit holds;
          })
        ];
      };
  };
  yen.aspects.settings-typed = {
    at = yen.kinds.member;
    errors = kits.settings-typed;
  };
  # a generator that an export carries goes to the machines of its `deploy` predicate
  yen.aspects.generators-from-exports = {
    at = yen.kinds.host;
    generators = yen.lib.batteries.vars.from-exports { inherit holds; };
  };
  # the disks kit disko gave a host become its `disko.devices`
  yen.aspects.disko-devices = {
    at = yen.kinds.host;
    nixos = yen.lib.batteries.disko { from = yen.kinds.host.sinks.disks; };
  };
  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
}
