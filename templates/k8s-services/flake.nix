{
  # apply on a k3s cluster (its helm-controller installs the charts): kubectl apply -f "$(nix build --print-out-paths .#lab)"
  description = "Kubernetes services as data: Helm charts and your own apps, scraped by Prometheus, shown in Grafana";

  outputs =
    inputs:
    inputs.yen.lib.mkFlake {
      inherit inputs;
      inherit (inputs.nixpkgs) lib;
    } (inputs.import-tree ./modules);

  inputs = {
    yen.url = "github:vic/yen";
    import-tree.url = "github:denful/import-tree";
    nixpkgs.url = "https://nixos.org/channels/nixos-25.05/nixexprs.tar.xz";
  };
}
