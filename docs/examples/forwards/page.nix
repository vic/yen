{
  title = "Forwards";
  description = "A sink key that names another sink feeds it. One sink can build another, and a guest can feed its host.";
  section = "behavior";
  order = 6;

  body =
    { docs, result, ... }:
    [
      ''
        The keys of a [sink](/behavior/sinks/), other than `reduce`, `of`, `at` and `out`, give elements to other sinks.
        They run at the receiver, with the receiver's args. You already know one: `out` gives to the flake
        (see [Flake outputs](/behavior/flake-outputs/)).

        In this example a host has a guest. The kinds are in
        [the example code](https://github.com/vic/yen/tree/main/docs/examples/forwards/modules/fleet.nix). These are the sinks:
      ''
      (docs.fileNoted "" "modules/sinks.nix")
      ''
        - At a host, `(1)` makes `ports` feed `config`: aspects give port numbers, and the host turns them into firewall config.
        - At a guest, `(2)` does the same.
        - At a guest, `(3)` is a key of `config` with its own name. A sink cannot feed itself, so this forward goes strictly up:
          to the nearest `config` sink above the guest, the host's.

        Aspects give the elements:
      ''
      (docs.fileNoted "" "modules/aspects.nix")
      ''
        `(1)` gives a port at every host. `(2)` is a `config` element at the guest `ci`.
        The guest's config arrives inside the host's config, under `vms.ci`:
      ''
      (docs.value result.flake.config)
      (docs.routes result)
      (docs.tip "One sink for two systems" ''
        Forwards let one sink serve several targets. A fleet can give `os` elements and forward them to `nixos` on a host
        and to `darwin` on a mac. Aspects write `os` once. See [nix-darwin machines](/recipes/darwin/).
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
      host = eq (result.flake.config.server.firewall.allowedTCPPorts) ([ 22 ]);
      guest-up = eq (result.flake.config.server.vms.ci) ({
        firewall.allowedTCPPorts = [ 8080 ];
        runner.enable = true;
      });
    };
}
