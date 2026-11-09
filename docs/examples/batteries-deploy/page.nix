{
  title = "Deploy and infrastructure batteries";
  description = "colmena and deploy-rs, terranix, Kubernetes manifests, machines writing config into each other, modules exported for other flakes.";
  section = "batteries";
  route = "batteries/deploy";
  order = 8;

  body =
    { docs, result, ... }:
    [
      ''
        A fleet that builds NixOS hosts often also deploys them, writes DNS records and Kubernetes manifests, and exports
        modules for other flakes. [Batteries](/batteries/) do each of these from a [sink](/behavior/sinks/), and this
        example uses all of them. The fleet spawns hosts, a cluster and an export, each a [kind](/model/kinds-fields/)
        with its own sinks.
      ''
      (docs.fileNoted "" "modules/fleet.nix")
      ''
        Each battery is the value of one key (`out`, `reduce` or a NixOS key), and it gets the sink it reads as a ref in `from`.

        - `(1)` collects the modules of every host in a colmena hive. The `out` key builds `colmenaHive`.
        - `(2)` collects terraform modules and builds `terraformConfigurations.dns` with terranix.
        - `(3)` has no `out`. Machines give modules to each other through it, and `elements` remembers who gave what.
        - `(4)` builds `nixosConfigurations` for each host.
        - `(5)` merges a cluster's manifests with the module system.
        - `(6)` is an export. It builds no machine, it gives `nixosModules.<name>` to other flakes.
        - `(7)` is a function in `yen.flake` that gives one deploy-rs node for each built NixOS configuration.

        The [aspects](/behavior/aspects/) fill these sinks. `machine` is active at every host and at the `base` export,
        and `hive` gives to the `colmena`, `terraform` and `nixos` sinks.
      ''
      (docs.fileNoted "" "modules/machines.nix")
      ''
        `(1)` and `(2)` give a host's hive entry and DNS record, read from `host.addr`. At `(3)`, `distributed.nodes` reads
        what other machines wrote for this one. At `(4)`, `lb` writes into `web`, so its backends know the load balancer.
        `(5)` and `(6)` are two aspects at the same cluster. Both write `axon`'s ingress, and the module system merges them:
      ''
      (docs.value result.flake.k8sManifests)
      ''
        ## The batteries

        Each battery, the value it is and what it gives:

        | Battery | Value of | Gives |
        |---|---|---|
        | `deploy.colmena { from; makeHive; meta; }` | `out` of a merge sink of `{ <host> = module; }` | `colmenaHive` |
        | `deploy.deploy-rs { configurations; hostname; activate; sshUser; }` | a function, in `yen.flake` | `deploy.nodes` from built configs |
        | `terranix.configuration { from; terranixConfiguration; system; name; }` | `out` of a terraform module sink | `terraformConfigurations.<name>` |
        | `k8s.manifests { from; lib; output; }` | `out` of a sink of manifest modules | `k8sManifests.<scope name>`, merged with the module system |
        | `distributed.nodes { from; }` | a NixOS key | the modules other machines wrote for this one |
        | `exports.modules { from; output; }` | `out` of a module sink at an export scope | `<output>.<scope name>` for other flakes |
      ''
    ];

  checks =
    {
      result,
      eq,
      yes,
      no,
      ...
    }:
    {
      outputs = eq (builtins.attrNames result.flake) ([
        "checks"
        "colmenaHive"
        "deploy"
        "k8sManifests"
        "nixosConfigurations"
        "nixosModules"
        "terraformConfigurations"
      ]);
      k8s = eq (result.flake.k8sManifests.axon.ingress.web) ({
        host = "web.example.org";
        port = 80;
        tls = true;
      });
      exports = eq (builtins.length result.flake.nixosModules.base.imports) (1);
      deploy-rs = eq (builtins.mapAttrs (_: n: n.hostname) result.flake.deploy.nodes) ({
        lb = "10.0.0.1";
        web = "10.0.0.2";
      });
    };

  e2e =
    {
      flake,
      eq,
      yes,
      no,
      ...
    }:
    {
      colmena = eq (builtins.attrNames flake.colmenaHive.nodes) ([
        "lb"
        "web"
      ]);
      deploy-rs = yes (builtins.isString flake.deploy.nodes.web.profiles.system.path.drvPath);
      terranix = yes (builtins.isString flake.terraformConfigurations.dns.drvPath);
      nodes = {
        t1 = eq (flake.nixosConfigurations.web.config.networking.extraHosts) ("10.0.0.1 lb.internal\n");
        t2 = eq (flake.nixosConfigurations.lb.config.networking.extraHosts) ("");
      };
    };
}
