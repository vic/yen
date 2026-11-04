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
        A bundle is a kit whose assemblies make more assemblies. One `homelab` assembly names the server and the nodes,
        and the base, wireguard, borg, monitoring and dns assemblies follow from those two roles. See
        [Kits batteries](/batteries/kits/) for kits, assemblies and roles. You import the kits a bundle uses, then write one assembly:
      ''
      (docs.fileNoted "" "modules/assemblies.nix")
      ''
        - `(1)` imports the bundle `homelab` and the kits it uses. The parts of `base` and `borg` come with them: `homelab` lists only its own.
        - `(2)` is the kit of the assembly. `lab` is the only assembly the fleet writes.
        - `(3)` is a setting of the server role: one of the layouts of the kit `disko`. A role's `settings` may also be a function of the machine, for a device per machine.
        - `(4)` is the role `node`. Its machines are `lb` and `web`.

        The fleet's words: hosts with an address, members of assemblies, and the sinks the library kits write to.
      ''
      (docs.fileNoted "" "modules/fleet.nix")
      ''
        - `(1)` expands the assemblies at every depth with the battery `kits.assemblies`. The parts of a bundle live under its assembly,
          keyed by a short name (`base`, `wg`), and are not names in the fleet.
        - `(2)` gives each host one member scope for each (assembly, role) it takes.
        - `(3)` is the `nixos` sink of the host. A kit's `os` keys go into it.
        - `(4)` is `kits.contract`. It refuses two assemblies with one name. `(5)` checks the types of the settings.
        - `(6)` gives a generator that an export carries to the machines of its `deploy` predicate.
      ''
      ''
        ## The result

        The members of each machine (a part is named by its path joined by `-`: `lab-base-disko` is part `disko` of part `base` of `lab`):
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
        What the members export:
      ''
      (docs.value members.exports)
      ''
        ## The contract

        `homelab` allows exactly one server. Two:
      ''
      (docs.file "variants/two-servers.nix")
      (docs.value (map (e: e.error) (variant "variants/two-servers.nix").errors))
      ''
        And none:
      ''
      (docs.file "variants/no-server.nix")
      (docs.value (map (e: e.error) (variant "variants/no-server.nix").errors))
      ''
        ## The bundles

        | Bundle | Roles | Adds |
        |---|---|---|
        | `base` | `default` with `device`, `layout` (one of `yen.kit.disko.layouts`), `authorizedKeys`, `hardware` | disko, facter, emergency-access, and sshd as server, on the same machines. No users: a user needs a name per machine |
        | `homelab` | `server` (exactly 1), `node`; the settings of `base` and `prefix` | base on both roles; wireguard (server controller, nodes peers); borg (server backs up); monitoring (server scrapes); dns on the server |

        The templates [kits-homelab](https://github.com/vic/yen/tree/main/templates/kits-homelab) and
        [kits-base](https://github.com/vic/yen/tree/main/templates/kits-base) are working examples.
      ''
    ];

  checks = import ./checks.nix;
}
