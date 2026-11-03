# Hosts with `sharedPkgs` reuse the pkgs of the first sharing host (the leader): nixpkgs is imported once.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  np = inputs.nixpkgs;
  # the leader of the host's group: the first sharing host of its system. `system` is data, so `==`; `same` compares refs only
  leaderOf =
    host: shared-pkgs:
    lib.head (
      lib.sort (a: b: a < b) (
        map (e: e.from.name) (lib.filter (e: e.from.system == host.system) shared-pkgs)
      )
    );
  isFollower = host: shared-pkgs: host.sharedPkgs && leaderOf host shared-pkgs != host.name;
  # the leader's built pkgs, read through the `out` arg, lazily
  readOnlyOf = out: leader: [
    np.nixosModules.readOnlyPkgs
    { options.nixpkgs.system = lib.mkOption { internal = true; }; }
    { nixpkgs.pkgs = out.nixosConfigurations.${leader}.pkgs; }
  ];
in
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  # the sharing hosts, at the fleet: a host reads its group through this sink, so the read is an edge
  yen.kinds.fleet.sinks.shared-pkgs.reduce = yen.lib.reduce.elements;
  yen.aspects.shared-pkgs = {
    at = yen.lib.all [
      yen.kinds.host
      (s: s.sharedPkgs)
    ];
    shared-pkgs = { host, ... }: host.name;
  };
  yen.kinds.host = {
    fields = {
      system = yen.lib.opt yen.lib.str "x86_64-linux";
      sharedPkgs = yen.lib.opt yen.lib.bool false;
    };
    sinks.nixos.out =
      {
        host,
        nixos,
        out,
        shared-pkgs,
        ...
      }:
      {
        nixosConfigurations.${host.name} = np.lib.nixosSystem {
          inherit (host) system;
          modules =
            nixos ++ lib.optionals (isFollower host shared-pkgs) (readOnlyOf out (leaderOf host shared-pkgs));
        };
        sharedLeader.${host.name} =
          if isFollower host shared-pkgs then leaderOf host shared-pkgs else null; # whose pkgs this host reuses
        ownPkgs.${host.name} = np.lib.nixosSystem {
          inherit (host) system;
          modules = nixos;
        }; # the oracle: the same host with its own pkgs
      };
  };

  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
}
