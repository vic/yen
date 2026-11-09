{
  title = "Bundles of the library";
  description = "A bundle is a kit whose assemblies make more assemblies: base for a new machine, homelab for a server and its nodes.";
  section = "batteries";
  route = "batteries/kits-bundles";
  order = 6;

  body =
    {
      docs,
      result,
      variant,
      ...
    }:
    let
      members = import ./members.nix result;
    in
    [
      ''
        A bundle is a kit whose assemblies make more assemblies. You write one `homelab` assembly that names the server
        and the nodes, and the base, wireguard, borg, monitoring and dns assemblies follow from those two roles. (See
        [Kits batteries](/batteries/kits/) for kits, assemblies and roles.) Import the kits the bundle uses, then write one assembly:
      ''
      (docs.fileNoted "" "modules/assemblies.nix")
      ''
        - `(1)` imports the `homelab` bundle and the kits it uses. The parts of `base` and `borg` come along with them, so `homelab` lists only its own.
        - `(2)` is the assembly's kit. `lab` is the only assembly the fleet writes.
        - `(3)` is a server role setting, one of the `disko` kit's layouts. A role's `settings` can also be a function of the machine, if you need a device per machine.
        - `(4)` is the `node` role, with the machines `lb` and `web`.

        The fleet brings its own words: hosts with an address, members of assemblies, and the sinks the library kits write to.
      ''
      (docs.fileNoted "" "modules/fleet.nix")
      ''
        - `(1)` expands the assemblies at every depth with the `kits.assemblies` battery. A bundle's parts live under its assembly,
          keyed by a short name (`base`, `wg`), so they aren't names in the fleet.
        - `(2)` gives each host one member scope for each (assembly, role) it takes.
        - `(3)` is the host's `nixos` sink, where a kit's `os` keys go.
        - `(4)` is `kits.contract`, which refuses two assemblies with the same name, and `(5)` checks the setting types.
        - `(6)` gives a generator that an export carries to the machines of its `deploy` predicate.
      ''
      ''
        ## The result

        Here are the members of each machine. A part is named by its path joined with `-`, so `lab-base-disko` is part `disko` of part `base` of `lab`:
      ''

      (docs.value (
        builtins.listToAttrs (
          map
            (m: {
              name = m;
              value = members.of m;
            })
            [
              "lb"
              "web"
              "nas"
            ]
        )
      ))
      ''
        And what they export:
      ''
      (docs.value members.exports)
      ''
        ## The contract

        `homelab` allows exactly one server. With two:
      ''
      (docs.file "variants/two-servers.nix")
      (docs.value (map (e: e.error) (variant "variants/two-servers.nix").errors))
      ''
        And with none:
      ''
      (docs.file "variants/no-server.nix")
      (docs.value (map (e: e.error) (variant "variants/no-server.nix").errors))
      ''
        ## The bundles

        | Bundle | Roles | Adds |
        |---|---|---|
        | `base` | `default` with `device`, `layout` (one of `yen.kit.disko.layouts`), `authorizedKeys`, `hardware` | disko, facter, emergency-access, and sshd as server, on the same machines. No users: a user needs a name per machine |
        | `homelab` | `server` (exactly 1), `node`; the settings of `base` and `prefix` | base on both roles; wireguard (server controller, nodes peers); borg (server backs up); monitoring (server scrapes); dns on the server |

        For working examples, see the [kits-homelab](https://github.com/vic/yen/tree/main/templates/kits-homelab) and
        [kits-base](https://github.com/vic/yen/tree/main/templates/kits-base) templates.
      ''
    ];

  checks = import ./checks.nix;
}
