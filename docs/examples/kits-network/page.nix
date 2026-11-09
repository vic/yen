{
  title = "Network kits";
  description = "Ready-made kits from yen.lib.kits: wireguard, zerotier and dns, with battery addresses.";
  section = "batteries";
  route = "batteries/kits-network";
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
        The library ships network kits: a VPN with a hub, a virtual network with moons, and DNS records. A kit is a
        [module](/principles/modules/), so your fleet only writes assemblies. [Kits batteries](/batteries/kits/) explains
        kits, assemblies and roles. Here are the fleet's own words and its assemblies:
      ''
      (docs.fileNoted "" "modules/network.nix")
      ''
        - `(1)` imports a kit that reads public values. It takes `{ root; }`, the vars directory. The kit is a value in Yen, not a file in your repo, so it can't
          find your vars by a relative path.
        - `(2)` is a wireguard assembly where `lb` is the hub and `web` and `db` are peers. Addresses come from the prefix, in member order.
        - `(3)` is a role taken by a predicate instead of a name.
        - `(4)` is a zerotier assembly: one controller, one moon, and every other machine as a peer.
        - `(5)` is one of the fleet's own kits, which gives endpoints, `(6)` is the aspect that gives them, and the `dns` kit reads them.

        Each wireguard member gets an address in member order, and a peer only sees the controller:
      ''
      (docs.value result.flake.config)
      ''
        dns reads the endpoints `site` exports:
      ''
      (docs.value result.flake.cnames)
      ''
        ## The kits

        | Kit | Roles | Interface | Does |
        |---|---|---|---|
        | `wireguard { root; }` | `controller` (exactly 1), `peer` | `prefix`, `port` (51820) | an address per member; keys by generators; the private key is a path, never in the store; a peer talks to the controller |
        | `zerotier { root; }` | `controller` (1), `moon` (0 to 4), `peer` | none | the controller's network id and the moons' ids are public generator files; peers join and list the moons |
        | `dns` | `default` | none | a record for every `endpoints` any kit exports |

        The `addresses` battery gives each member an address from a prefix, in member order. A repeated address, a prefix
        that isn't an IPv4 /16 to /24, and a prefix that's too small are all error records.

        ## The contract

        A wireguard or zerotier network needs exactly one controller, zerotier allows at most four moons, and a prefix
        must be big enough for its members.
      ''
      (docs.file "variants/five-moons.nix")
      (docs.value (map (e: e.error) (variant "variants/five-moons.nix").errors))
      (docs.value (map (e: e.error) (variant "variants/no-controller.nix").errors))
      (docs.value (map (e: e.error) (variant "variants/two-controllers.nix").errors))
      (docs.value (map (e: e.error) (variant "variants/small-prefix.nix").errors))
      ''
        All members of one wireguard assembly must name the same prefix, and every member needs its public file in
        `vars`. A missing file is an error record, never some text in the configuration:
      ''
      (docs.file "variants/prefix-differs.nix")
      (docs.value (map (e: e.error) (variant "variants/prefix-differs.nix").errors))
      (docs.file "variants/missing-public.nix")
      (docs.value (map (e: e.error) (variant "variants/missing-public.nix").errors))
    ];

  checks = import ./checks.nix;
}
