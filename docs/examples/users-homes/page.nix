{
  title = "Users and homes";
  description = "home-manager inside NixOS and as a standalone home, from one aspect.";
  section = "recipes";
  order = 1;

  body =
    { docs, result, ... }:
    [
      ''
        People use several machines, and some of them run NixOS while others only run home-manager. In Yen a person is
        data, and their home is one [aspect](/behavior/aspects/) that is active in both places.
      ''
      (docs.fileNoted "{11,16}" "modules/fleet.nix")
      ''
        - At `(2)`, a `user` lives under each host in its `hosts`, and at `(3)`, its `homeManager` sink forwards into the host's NixOS.
        - At `(1)`, a `home` lives under the fleet, and at `(4)`, its `homeManager` sink builds `homeConfigurations.<name>`.

        This file declares alice, her home and her aspects:
      ''
      (docs.fileNoted "{6-8}" "modules/alice.nix")
      ''
        At `(1)`, alice lives on the host `server`. At `(2)`, her home `alice@laptop` has no host. At `(3)`, `alice-home`
        is active at her scopes and her homes, and gives one `homeManager` module. Here is the host:
      ''
      (docs.file "modules/machines.nix")
      ''
        `alice-home` is active at alice's user scope and at her home:
      ''
      (docs.value result.active.alice-home)
      (docs.scopes result)
      (docs.sh ''
        sudo nixos-rebuild switch --flake .#server
        home-manager switch --flake '.#alice@laptop'
      '')
      (docs.tip "A home that reads its host" ''
        A home can also live under a host: give `host` a `spawns.home`. The home then reads the host's sinks like any
        child does, and still builds its own `homeConfigurations`. A home sink with no keys keeps its content away from the host.
        See [Routing and walls](/behavior/routing/#walls).
      '')
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
      both = {
        t1 = yes (result.active.alice-home."fleet:main/home:alice@laptop");
        t2 = yes (result.active.alice-home."fleet:main/host:server/user:alice");
      };
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
      nixos-home = eq (flake.nixosConfigurations.server.config.home-manager.users.alice.programs.git.userName) (
        "Alice"
      );
      standalone = eq (flake.homeConfigurations."alice@laptop".config.programs.git.userName) ("Alice");
      standalone-builds = yes (flake.homeConfigurations."alice@laptop".activationPackage ? drvPath);
    };
}
