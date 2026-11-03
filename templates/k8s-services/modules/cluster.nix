# A cluster holds apps. An app is a kind of the cluster: a Helm chart, which the k3s helm-controller installs (no
# chart is rendered in Nix), or an image (a Deployment, a Service and an Ingress). An app with a metrics port gets a
# ServiceMonitor, so Prometheus scrapes it. The aspects that turn an app into manifests belong to the app kind.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  meta = app: {
    inherit (app) name namespace;
  };
  manifests = yen.lib.batteries.k8s.manifests {
    from = yen.kinds.cluster.sinks.k8s;
    inherit lib;
  };
in
{
  yen.kinds.fleet = {
    spawns.cluster = _: yen.cluster;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.fleet.main = { };
  yen.flake = { out, ... }: out;

  yen.kinds.cluster = {
    fields.domain = yen.lib.str;
    # the manifests of the cluster's apps, and one list of them for `kubectl apply -f`
    # (an element gets only the args it names: the battery reads `scope` and `sinks`)
    sinks.k8s.out =
      args@{
        cluster,
        scope,
        sinks,
        ...
      }:
      let
        m = (manifests args).k8sManifests.${cluster.name};
      in
      {
        k8sManifests.${cluster.name} = m;
        packages.x86_64-linux.${cluster.name} = pkgs.writeText "${cluster.name}.json" (
          builtins.toJSON {
            apiVersion = "v1";
            kind = "List";
            items = lib.attrValues m;
          }
        );
      };
    kinds.app = {
      fields = {
        namespace = yen.lib.opt yen.lib.str "default";
        chart = yen.lib.maybe yen.lib.attrs; # { repo; chart; version ? ; values ? { }; }
        image = yen.lib.maybe yen.lib.str;
        port = yen.lib.opt yen.lib.port 8080;
        metrics = yen.lib.maybe yen.lib.port; # the port Prometheus scrapes
      };
      aspects = {
        helm = {
          at = s: s.chart or null != null;
          k8s =
            { app, ... }:
            {
              "${app.name}-chart" = {
                apiVersion = "helm.cattle.io/v1";
                kind = "HelmChart";
                metadata = {
                  inherit (app) name;
                  namespace = "kube-system";
                };
                spec = {
                  inherit (app.chart) repo chart;
                  targetNamespace = app.namespace;
                  createNamespace = true;
                  valuesContent = builtins.toJSON (app.chart.values or { });
                }
                // lib.optionalAttrs (app.chart ? version) { inherit (app.chart) version; };
              };
            };
        };
        deployment = {
          at = s: s.image or null != null;
          k8s =
            { app, cluster, ... }:
            {
              "${app.name}-deployment" = {
                apiVersion = "apps/v1";
                kind = "Deployment";
                metadata = meta app;
                spec = {
                  selector.matchLabels.app = app.name;
                  template = {
                    metadata.labels.app = app.name;
                    spec.containers = [
                      {
                        inherit (app) name image;
                        ports = [ { containerPort = app.port; } ];
                      }
                    ];
                  };
                };
              };
              "${app.name}-service" = {
                apiVersion = "v1";
                kind = "Service";
                metadata = meta app // {
                  labels.app = app.name;
                };
                spec = {
                  selector.app = app.name;
                  ports = [
                    {
                      name = "http";
                      port = app.port;
                    }
                  ]
                  ++ lib.optional (app.metrics != null) {
                    name = "metrics";
                    port = app.metrics;
                  };
                };
              };
              "${app.name}-ingress" = {
                apiVersion = "networking.k8s.io/v1";
                kind = "Ingress";
                metadata = meta app;
                spec.rules = [
                  {
                    host = "${app.name}.${cluster.domain}";
                    http.paths = [
                      {
                        path = "/";
                        pathType = "Prefix";
                        backend.service = {
                          inherit (app) name;
                          port.number = app.port;
                        };
                      }
                    ];
                  }
                ];
              };
            };
        };
        # kube-prometheus-stack scrapes every app with a metrics port: uptime and request statistics in Grafana
        metrics = {
          at = s: s.metrics or null != null;
          k8s =
            { app, ... }:
            {
              "${app.name}-monitor" = {
                apiVersion = "monitoring.coreos.com/v1";
                kind = "ServiceMonitor";
                metadata = meta app;
                spec = {
                  selector.matchLabels.app = app.name;
                  endpoints = [ { port = "metrics"; } ];
                };
              };
            };
        };
      };
    };
  };
}
