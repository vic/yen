# Clusters under an environment. Discovery (den collect): k3s nodes reduce at the environment; the reader filters.
{ yen, lib, ... }:
let
  inherit (yen.lib) maybe same;
  inherit (yen.lib.reduce) elements;
  clusterOf = h: lib.findFirst (c: lib.any (same h) c.hosts) null (lib.attrValues yen.cluster); # for `at`
  clusters.instances = yen.kinds.cluster; # a tree request: every cluster, with its data
  members = c: lib.filter (e: lib.any (same e.from) c.hosts);
  # the first k3s node of the host's cluster, among the clusters cs
  firstNode =
    cs: host: es:
    lib.head (members (lib.findFirst (c: lib.any (same host) c.hosts) null cs) es);
  # the first node starts the cluster, the others join it
  k3sOf =
    host: first:
    {
      services.k3s.enable = true;
    }
    // (
      if same first.from host then
        { services.k3s.clusterInit = true; }
      else
        { services.k3s.serverAddr = "https://${first.value}:6443"; }
    );
in
{
  yen.kinds.environment.spawns.cluster = yen.lib.pointing "environment" yen.cluster;
  yen.kinds.cluster = {
    fields = {
      environment = yen.kinds.environment;
      hosts = yen.lib.listOf yen.kinds.host;
      ingestUrl = maybe yen.lib.str;
    };
    sinks.k8s-manifests.out = yen.lib.batteries.k8s.manifests {
      from = yen.kinds.cluster.sinks.k8s-manifests;
      inherit lib;
    };
  };
  yen.cluster.axon = {
    environment = yen.environment.prod;
    hosts = [
      yen.host.web-1
      yen.host.web-2
    ];
    ingestUrl = "https://ingest.example.org";
  };
  yen.aspects.axon = {
    at = yen.cluster.axon;
    k8s-manifests.target.branch = "main";
  };

  yen.kinds.environment.sinks.k3s-nodes.reduce = elements;
  yen.aspects.k3s = {
    at = s: clusterOf s != null;
    k3s-nodes = { host, ... }: host.addr;
    # The first node starts the cluster, the others join it. `at` puts the host among its cluster's nodes, so the list is never empty.
    cycle =
      {
        tree,
        scope,
        k3s-nodes,
        ...
      }:
      {
        tree = [ clusters ];
        # a list literal: its length is known without reading k3s-nodes, which reduces from these very elements
        nixos = [ (k3sOf scope (firstNode (tree.select clusters) scope (lib.head k3s-nodes))) ];
      };
  };
  yen.aspects.k3s-registries = {
    at = yen.kinds.cluster;
    k8s-manifests =
      { cluster, k3s-nodes, ... }:
      {
        applications.k3s.nodes = map (e: e.value) (members cluster k3s-nodes);
      };
  };

  # Across environments: reduce at the fleet, filter by a ref field.
  yen.kinds.environment.fields.monitoring = maybe yen.kinds.cluster;
  yen.environment.prod.monitoring = yen.cluster.axon;
  yen.kinds.fleet.sinks.monitoring-ingest.reduce = elements;
  yen.aspects.ingest = {
    at = yen.lib.all [
      yen.kinds.cluster
      (s: s.ingestUrl != null)
    ];
    monitoring-ingest = { cluster, ... }: cluster.ingestUrl;
  };
  yen.aspects.alloy = {
    at = yen.helpers.linux;
    nixos =
      { monitoring-ingest, environment, ... }:
      {
        environment.etc."alloy/endpoints".text = lib.concatLines (
          map (e: e.value) (
            lib.filter (
              e: environment.monitoring != null && same e.from environment.monitoring
            ) monitoring-ingest
          )
        );
      };
  };
}
