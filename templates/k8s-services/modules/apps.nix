# The cluster and its apps are data: two Helm charts, and two apps that run an image. Pin a chart with `version`.
{
  yen.cluster.lab = {
    domain = "lab.example.org";
    app = {
      gitea = {
        namespace = "git";
        chart = {
          repo = "https://dl.gitea.com/charts/";
          chart = "gitea";
        };
      };
      monitoring = {
        namespace = "monitoring";
        chart = {
          repo = "https://prometheus-community.github.io/helm-charts";
          chart = "kube-prometheus-stack";
          values.grafana.enabled = true;
        };
      };
      # a Matrix homeserver
      conduit = {
        namespace = "matrix";
        image = "matrixconduit/matrix-conduit:latest";
        port = 6167;
      };
      # your own Go API: an image you build and push. Prometheus scrapes its /metrics on port 9090
      api = {
        namespace = "apps";
        image = "ghcr.io/example/api:1.0.0";
        metrics = 9090;
      };
    };
  };
}
