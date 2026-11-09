{
  title = "osConfig in home-manager";
  description = "A home-manager module reads its host's NixOS config, nested in NixOS or as a standalone home.";
  section = "recipes";
  order = 8;

  body =
    { docs, ... }:
    [
      ''
        A home-manager module often needs its host's NixOS config: `{ osConfig, pkgs, ... }:`. For the basics, see
        [NixOS system and home](/nixos/system-and-home/). In Yen, `osConfig` is a [sink](/behavior/sinks/): each host
        gives its realized config to it, and a module asks for it like any other sink arg. `pkgs` stays open, so
        home-manager fills in its own `pkgs`.
      ''
      (docs.fileNoted "{12-24,54-57}" "modules/fleet.nix")
      ''
        - At `(1)`, a host spawns its users and homes. At `(2)`, the `osConfig` sink takes one value.
        - At `(3)`, a user gives `homeManager` modules to its host's NixOS. At `(4)`, a standalone home builds `homeConfigurations`.
        - At `(5)`, the `home-manager` aspect adds the home-manager module to NixOS, below users.
        - At `(6)`, the `os-config` [aspect](/behavior/aspects/) gives `out.nixosConfigurations.<host>.config`. It's lazy, so Nix reads it only when a module asks.

        This file declares alice and her home:
      ''
      (docs.fileNoted "{23-32}" "modules/alice.nix")
      ''
        At `(1)`, alice lives on the host `server`. At `(2)`, her standalone home has `on`, so it lives under that host:
        it reads the host's sinks like any child and still builds `homeConfigurations`. At `(3)`, one `at` list holds
        alice and her homes. At `(4)`, the module asks for `osConfig` from the sink and for home-manager's `pkgs`.

        `editors` lands in two places, the server's NixOS (`home-manager.users.alice`) and
        `homeConfigurations."alice@server"`, and both read the same `osConfig`.
      ''
      (docs.sh ''
        sudo nixos-rebuild switch --flake .#server
        home-manager switch --flake '.#alice@server'
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
        t1 = yes (result.active.editors."fleet:main/host:server/home:alice@server");
        t2 = yes (result.active.editors."fleet:main/host:server/user:alice");
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
    let
      nano = c: builtins.any (p: (p.pname or "") == "nano") c.home.packages;
      nested = flake.nixosConfigurations.server.config.home-manager.users.alice;
      standalone = flake.homeConfigurations."alice@server".config;
    in
    {
      nested = {
        t1 = eq (nested.home.sessionVariables.EDITOR_HOST) ("server");
        t2 = yes (nano nested);
      };
      standalone = {
        t1 = eq (standalone.home.sessionVariables.EDITOR_HOST) ("server");
        t2 = yes (nano standalone);
      };
      standalone-builds = yes (flake.homeConfigurations."alice@server".activationPackage ? drvPath);
    };
}
