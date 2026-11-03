{
  title = "Install and deploy kits";
  description = "Disk layouts as data, the disko and facter kits, install apps with nixos-anywhere, rebuild apps with nixos-rebuild.";
  section = "batteries";
  route = "batteries/install";
  order = 9;

  body =
    {
      docs,
      result,
      variant,
      ...
    }:
    [
      ''
        The install lane has three batteries and two kits. The flake [sink](/behavior/sinks/) carries `apps` like any other output: an
        `out` value that gives `apps.<system>.<name>` merges with the rest.

        | Battery | Value of | Gives |
        |---|---|---|
        | `disko { from; }` | a NixOS key | `disko.devices`: the merge of what the machine gave to sink `from` |
        | `install.apps { from; pkgs; report; target; flake; }` | `out` of the machine's disks sink | `apps.<system>.install-<machine>`: nixos-anywhere with the disko layout, writing the facter report to the path `report` gives for the machine |
        | `deploy.rebuild { from; pkgs; flake; }` | `out` of the machine's deploy sink | `apps.<system>.rebuild-<machine>`: `nixos-rebuild switch --target-host user@address`, with `--build-host` when the deploy target has a `buildHost` |

        App names come from the [scope](/model/scopes/) name. No disks element, no install app; no deploy target, no rebuild app.
        Arguments after `--` go to the tool: a deploy user that is not root runs `nix run .#rebuild-<machine> -- --sudo`.
        `report` is a function from the machine to a path, such as `./facter/<machine>.json`. Point it into the directory
        you give kit `facter` as `dir`: kit `facter` reads `<dir>/<machine>.json`. Commit the report after the install,
        and the next build uses it. A machine with no report gets no facter config.

        | Kit | Role | Interface | Does |
        |---|---|---|---|
        | `lib.kits.disko` | `default` | `device` (str), `layout` (ref to a layout) | gives the layout's disko devices to sink `disks`; owns the [kind](/model/kinds-fields/) `layout` |
        | `lib.kits.facter` | `default` | `dir` (path) | imports `<dir>/<machine>.json` with `nixos.facter` |

        A kit is a [module](/principles/modules/): put `inputs.yen.lib.kits.disko` in `imports` of the top module.

        ## Layouts

        `layout` is a data kind owned by the kit `disko`. Each layout is `yen.layout.<name>` with a `devices` function
        of the device string: `single-ext4`, `btrfs-luks` and `zfs-mirror` (two devices, separated by a space).
      ''
      (docs.file "modules/fleet.nix")
      (docs.file "modules/assemblies.nix")
      ''
        ## The result

        The disk layouts reach each machine's `disko.devices`, and the facter report its `hardware.facter.reportPath`:
      ''
      (docs.value (
        builtins.mapAttrs (_: c: builtins.attrNames (c.disko.devices.disk or { })) result.flake.config
      ))
      ''
        The apps, one per machine that has the input:
      ''
      (docs.value (builtins.attrNames result.flake.apps.x86_64-linux))
      ''
        ## A layout is a ref

        A string where the layout goes is an error record, not a silent default:
      ''
      (docs.file "variants/layout-string.nix")
      (docs.value (map (e: e.error) (variant "variants/layout-string.nix").errors))
    ];

  checks = import ./checks.nix;
}
