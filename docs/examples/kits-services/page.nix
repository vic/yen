{
  title = "Kits of the library";
  description = "Ready-made kits for backups, wifi, remote builders, a binary cache, monitoring and postgres: the fleet writes only assemblies.";
  section = "batteries";
  route = "batteries/kits-services";
  order = 5;

  body =
    {
      docs,
      result,
      variant,
      ...
    }:
    [
      ''
        The library ships ready-made kits for services: backups, wifi, remote builders, a binary cache, monitoring and a database.
        A kit is a [module](/principles/modules/), so you import it and then write an assembly that puts your machines in its roles.
        (See [Kits batteries](/batteries/kits/) for kits, assemblies and roles.) The fleet only writes the assemblies:
      ''
      (docs.fileNoted "" "modules/assemblies.nix")
      ''
        - `(1)` imports the kits. `nix-cache` takes `{ root; }`, the vars directory it reads the public key from.
        - `(2)` is a fleet kit, `sshd`, with a role. The `borg` kit adds an assembly of it.
        - `(3)` is the kit of the `backup` assembly, and `(4)` puts `nas` in its server role. The other roles take machines the same way.
        - `(5)` is a setting of the `default` role, a set of networks, and `(6)` is a setting of the database client.

        The kits need an `addr` machine field. The sinks and the contract are the fleet's own words, just like on the
        [kits battery page](/batteries/kits/):
      ''
      (docs.fileNoted "" "modules/fleet.nix")
      ''
        - `(1)` expands the assemblies, plus the parts their kits add.
        - `(2)` is the exports sink, and `(3)` is the generators sink for the secrets the kits generate.
        - `(4)` gives each host one member [scope](/model/scopes/) for each (assembly, role) it takes.
        - `(5)` is the contract, and `(6)` checks the setting types.
        - `(7)` gives a generator that an export carries to the machines of its `deploy` predicate.
      ''
      ''
        ## The result

        The web host builds on the nas, uses its cache, and runs the node exporter and the borg job:
      ''
      (docs.value result.flake.config.web)
      ''
        The monitoring server reads one scrape job for each exporter in its assembly:
      ''
      (docs.value result.flake.config.lb.services.prometheus.scrapeConfigs)
      ''
        And here are the secrets the kits generate, as the nas vars plan:
      ''
      (docs.value result.flake.varsPlan.nas.files)
      ''
        ## The contract

        nix-cache allows one server. Here's a cache with two:
      ''
      (docs.file "variants/two-servers.nix")
      (docs.value (map (e: e.error) (variant "variants/two-servers.nix").errors))
      ''
        A database with a client and no machine for the server role:
      ''
      (docs.file "variants/no-server.nix")
      (docs.value (map (e: e.error) (variant "variants/no-server.nix").errors))
      ''
        A setting of the wrong type, and a port that isn't a port:
      ''
      (docs.file "variants/wrong-type.nix")
      (docs.value (map (e: e.error) (variant "variants/wrong-type.nix").errors))
      ''
        If the cache server has no generated public key in the vars directory, that's an error, never an "absent" key:
      ''
      (docs.file "variants/no-key.nix")
      (docs.value (map (e: e.error) (variant "variants/no-key.nix").errors))
      ''
        ## The kits

        Each kit has roles, a typed interface, limits, exports and [aspects](/behavior/aspects/). A client reads what
        the servers of its own assembly export, never another assembly's.

        | Kit | Roles | Server exports | Client does |
        |---|---|---|---|
        | `borg` | `client`, `server` (1) | `repo`, a known-hosts generator for the clients | `services.borgbackup.jobs` |
        | `wifi` | `default` with `networks` | | `/etc/wifi/networks`; a generator `wifi.<assembly>.<network>` per network, shared by all machines of the role, with one secret file `psk` |
        | `remote-builders` | `builder` (1 or more), `client` | `host`, `systems`, `speedFactor` | `nix.buildMachines`, with the battery `nixos.remote-builders` |
        | `nix-cache` | `server` (1), `client` | `url`, `key` (the ref of the generated `cache-key.pub`); a signing-key generator; harmonia with the `cache-key.pem` path | `nix.settings.substituters` and `trusted-public-keys`, read from the public var |
        | `monitoring` | `server` (1), `exporter` | exporter: `target` | server: `services.prometheus.scrapeConfigs`, one job per exporter |
        | `postgres` | `server` (1), `client` with `database`, `user` | `dsn` | server: the roles and databases, listens, one `pg_hba` line per client of its own assembly; client: its connection string |
      ''
    ];

  checks = import ./checks.nix;
}
