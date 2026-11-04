{
  title = "Guests inside hosts";
  description = "Containers or VMs as scopes under their host. A guest's NixOS goes into the host, never the other way.";
  section = "recipes";
  order = 4;

  body =
    { docs, result, ... }:
    [
      ''
        A guest is a machine that runs inside a host: a NixOS container here, a microvm in the
        [reference fleet](https://github.com/vic/yen/blob/main/reference/modules/platforms/microvm.nix).
        It is a [scope](/model/scopes/) under its host, with its own `nixos` [sink](/behavior/sinks/). That sink forwards its modules up, into the host.
        The kinds:
      ''
      (docs.fileNoted "{22-23}" "modules/kinds.nix")
      ''
        At `(1)`, `spawns.guest` makes each guest a scope under the host that it points to with `on`. At `(2)`, `on` is a ref to a host.
        At `(3)`, the `nixos` sink of the guest forwards its modules to the `nixos` sink of the host. At `(4)`, they become the
        `config` of a NixOS container. These are the machines:
      ''
      (docs.fileNoted "" "modules/machines.nix")
      ''
        At `(1)`, the guest `web` runs on `box`. These [aspects](/behavior/aspects/) give content to the guests:
      ''
      (docs.fileNoted "" "modules/services.nix")
      ''
        At `(1)`, `guest-base` is active at every guest. At `(2)`, `nginx` is active at the guest `web` only. These are the routes:
      ''
      (docs.routes result)
      ''
        `nginx` runs in the `web` container. The host `box` does not get it: the element went to `web`'s own sink.
      ''
      (docs.caution "Content flows up only" ''
        A host aspect never reaches its guests. To give every guest something, write an aspect with `at = yen.kinds.guest`,
        or `within` a host.
      '')
      (docs.sh "sudo nixos-rebuild switch --flake .#box   # builds box and both containers")
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
      nginx-at-guest = {
        t1 = yes (result.active.nginx."fleet:main/host:box/guest:web");
        t2 = no (result.active.nginx."fleet:main/host:box");
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
      c = flake.nixosConfigurations.box.config;
    in
    {
      web = yes (c.containers.web.config.services.nginx.enable);
      db = yes (c.containers.db.config.services.postgresql.enable);
      host-clean = no (c.services.nginx.enable);
    };
}
