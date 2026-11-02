#: lib.batteries.nixos.system :: { from; nixpkgs; } -> out value -- nixosConfigurations.<scope name>
# nixosConfigurations.<scope name> from the modules collected in `from`
#   yen.kinds.host.sinks.nixos.out = nixos.system { from = yen.kinds.host.sinks.nixos; inherit nixpkgs; };
self:
{ from, nixpkgs }:
self.batteries.configurations {
  inherit from;
  output = "nixosConfigurations";
  build = _: modules: nixpkgs.lib.nixosSystem { inherit modules; };
}
