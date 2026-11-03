# NixOS hosts: the nixos sink builds the system; os fans out to nixos (#76).
{ yen, lib, ... }:
let
  inherit (yen.lib) same;
  inherit (yen.lib.reduce) one;
  modlists = (import ./_modlists.nix).checked;
  # trimmedModules: the host evaluates a smaller base module list (_modlists.nix), in module-list.nix order
  trimmedOf = host: host.trimmedModules && modlists ? ${host.name};
  # filter module-list.nix itself: path values stay paths, inline (non-path) entries stay, order stays
  keepOf =
    np: host:
    lib.genAttrs (map (
      p: builtins.unsafeDiscardStringContext "${np}/nixos/modules/${p}"
    ) modlists.${host.name}) (_: true); # keys only: attr names hold no context
  baseIn =
    np: keep:
    lib.filter (p: !(builtins.isPath p) || keep ? ${builtins.unsafeDiscardStringContext (toString p)}) (
      import "${np}/nixos/modules/module-list.nix"
    );
  buildOf =
    host: full: ms:
    host.channel.nixpkgs.lib.nixosSystem (
      {
        system = host.system.name;
        modules = ms;
      }
      // lib.optionalAttrs (trimmedOf host && !full) {
        baseModules = baseIn host.channel.nixpkgs (keepOf host.channel.nixpkgs host);
      }
    );
  # the first sharing host of the host's (channel, system)
  leaderOf =
    host: shared-pkgs:
    lib.head (
      lib.sort (a: b: a < b) (
        map (e: e.from.name) (
          lib.filter (e: same e.from.channel host.channel && same e.from.system host.system) shared-pkgs
        )
      )
    );
  isFollower = host: shared-pkgs: host.sharedPkgs && leaderOf host shared-pkgs != host.name;
  readOnlyOf = np: shared: [
    np.nixosModules.readOnlyPkgs
    { options.nixpkgs.system = np.lib.mkOption { internal = true; }; }
    {
      nixpkgs.pkgs = shared;
      nixpkgs.overlays = np.lib.mkForce shared.overlays;
      nixpkgs.config = np.lib.mkForce shared.config;
    }
  ];
  # the host's modules, with the leader's pkgs (read through the `out` arg, lazily) when it follows
  modulesOf =
    host: nixos: out: shared-pkgs:
    nixos
    ++ lib.optionals (isFollower host shared-pkgs) (
      readOnlyOf host.channel.nixpkgs out.nixosConfigurations.${leaderOf host shared-pkgs}.pkgs
    );
in
{
  # a host on shared pkgs keeps docs off: the manual, man pages and option help differ when pkgs is shared
  yen.aspects.shared-pkgs-no-docs = {
    at = yen.lib.all [
      yen.kinds.host
      (s: s.sharedPkgs)
    ];
    nixos.documentation = {
      enable = false;
      nixos.enable = false;
      man.enable = false;
    };
  };
  # the hosts on shared pkgs, at the fleet: a host reads its group through this sink, so the read is an edge
  yen.kinds.fleet.sinks.shared-pkgs.reduce = yen.lib.reduce.elements;
  yen.aspects.shared-pkgs = {
    at = yen.lib.all [
      yen.kinds.host
      (s: s ? addr && s.sharedPkgs)
    ];
    shared-pkgs = { host, ... }: host.name;
  };
  yen.kinds.host = {
    fields = yen.kinds.machine.fields;
    spawns = {
      user = yen.helpers.usersOn;
      guest = yen.lib.pointing "on" yen.guest;
    };
    sinks = {
      nixos = {
        # Shared pkgs: hosts with `sharedPkgs` on one (channel, system) reuse the pkgs of the first of them (the leader)
        # through nixpkgs' readOnlyPkgs, so nixpkgs is imported once per group. `nixosConfigurationsOwnPkgs` keeps each
        # follower's build with its own pkgs, so a check can prove both give the same toplevel drvPath.
        out =
          {
            host,
            nixos,
            deploy,
            out,
            shared-pkgs,
            ...
          }:
          {
            nixosConfigurations.${host.name} = buildOf host false (modulesOf host nixos out shared-pkgs);
            nixosConfigurationsOwnPkgs = lib.optionalAttrs (isFollower host shared-pkgs) {
              ${host.name} = buildOf host true nixos;
            }; # a reference build: own pkgs, full module list
            nixosConfigurationsFull = lib.optionalAttrs (trimmedOf host) {
              ${host.name} = buildOf host true (modulesOf host nixos out shared-pkgs);
            }; # the oracle: same drvPath as the trimmed build
            sharedPkgs = lib.optionalAttrs host.sharedPkgs {
              ${host.name} = {
                leader = leaderOf host shared-pkgs;
                follower = isFollower host shared-pkgs;
              };
            };
            deploy.nodes.${host.name} = {
              hostname = deploy.address;
              sshUser = deploy.user;
            };
            # the `out` arg: this host's system, built once above
            ageManifest.${host.name} = lib.attrNames out.nixosConfigurations.${host.name}.config.age.secrets;
          };
        colmena =
          {
            host,
            scope,
            nixos,
            deploy,
            tags,
            ...
          }:
          {
            # tags: a source; roles: active aspects (hasAspect = holds)
            ${host.name} = {
              imports = nixos;
              deployment = {
                targetHost = deploy.address;
                tags = [
                  host.environment.name
                ]
                ++ tags
                ++ lib.filter (n: yen.lib.holds yen.aspects."role-${n}" scope) [
                  "server"
                  "workstation"
                  "laptop"
                ];
              };
            };
          };
      };
      os.nixos =
        { os, ... }:
        {
          imports = os;
        };
      deploy.reduce = one;
    };
  };
}
