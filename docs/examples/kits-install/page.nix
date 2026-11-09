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
        The install lane turns a machine's disk layout and hardware report into an install command, and gives you a
        deploy command too. The flake [sink](/behavior/sinks/) carries `apps` like any other output, so an `out` value
        that gives `apps.<system>.<name>` merges with the rest. The two kits are [modules](/principles/modules/), so you
        put them in the top module's `imports`. [Kits batteries](/batteries/kits/) explains kits and assemblies.
      ''
      (docs.fileNoted "" "modules/fleet.nix")
      ''
        - `(1)` imports the `disko` and `facter` kits.
        - `(2)` is the disks sink's `out`. It gives the app `install-<machine>`, nixos-anywhere with the disko layout,
          which writes the facter report to the path `report` gives for that machine. The app name comes from the [scope](/model/scopes/) name.
        - `(3)` is the deploy sink's `out`. It gives the app `rebuild-<machine>`, `nixos-rebuild switch --target-host user@address`,
          and adds `--build-host` when the deploy target has a `buildHost`.
        - `(4)` is the disks sink's NixOS key, where `disko.devices` is the merge of what the machine gave there.

        No disks element means no install app, and no deploy target means no rebuild app. Arguments after `--` go to the
        tool, so a deploy user that isn't root runs `nix run .#rebuild-<machine> -- --sudo`.

        The assemblies of the two kits:
      ''
      (docs.fileNoted "" "modules/assemblies.nix")
      ''
        `(1)` checks the settings' types. At `(2)`, `layout` is a ref to one of the `disko` kit's layouts,
        `yen.kit.disko.layouts.<name>`. A layout is a value of the kit, not a kind, so the kit adds no name outside
        itself. Each layout has a `devices` function of the device string: `single-ext4`, `btrfs-luks` and `zfs-mirror`
        (two devices, separated by a space). At `(3)`, `dir` is the directory with one facter report per machine, and
        the `facter` kit reads `<dir>/<machine>.json`. The install app's `report` is a function from the machine to a
        path, like `./facter/<machine>.json`, so point it into that directory. Commit the report after the install and
        the next build uses it. A machine with no report gets no facter config.
      ''
      ''
        ## The result

        The disk layouts reach each machine's `disko.devices`, and the facter report reaches its `hardware.facter.reportPath`:
      ''
      (docs.value (
        builtins.mapAttrs (_: c: builtins.attrNames (c.disko.devices.disk or { })) result.flake.config
      ))
      ''
        The apps, one for each machine that has the input:
      ''
      (docs.value (builtins.attrNames result.flake.apps.x86_64-linux))
      ''
        ## A layout is a value of the kit

        Putting a string where the layout goes gives an error record, not a silent default:
      ''
      (docs.file "variants/layout-string.nix")
      (docs.value (map (e: e.error) (variant "variants/layout-string.nix").errors))
      ''
        ## The batteries and kits

        | Battery | Value of | Gives |
        |---|---|---|
        | `disko { from; }` | a NixOS key | `disko.devices`: the merge of what the machine gave to sink `from` |
        | `install.apps { from; pkgs; report; target; flake; }` | `out` of the machine's disks sink | `apps.<system>.install-<machine>`: nixos-anywhere with the disko layout, writing the facter report to the path `report` gives for the machine |
        | `deploy.rebuild { from; pkgs; flake; }` | `out` of the machine's deploy sink | `apps.<system>.rebuild-<machine>`: `nixos-rebuild switch --target-host user@address`, with `--build-host` when the deploy target has a `buildHost` |

        | Kit | Role | Interface | Does |
        |---|---|---|---|
        | `lib.kits.disko` | `default` | `device` (str), `layout` (one of `yen.kit.disko.layouts`) | gives the layout's disko devices to sink `disks`; owns its layouts, `yen.kit.disko.layouts` |
        | `lib.kits.facter` | `default` | `dir` (path) | imports `<dir>/<machine>.json` with `nixos.facter` |
      ''
    ];

  checks = import ./checks.nix;
}
