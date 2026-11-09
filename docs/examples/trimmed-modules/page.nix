{
  title = "Trimmed module lists";
  description = "Evaluate only the NixOS base modules a host needs, with a drvPath check that proves the system stays the same.";
  section = "perf";
  order = 3;
  badge = "advanced";

  body =
    { docs, ... }:
    [
      ''
        NixOS evaluates about 1,900 base modules for every host, whether it uses them or not. In the
        [reference fleet](https://github.com/vic/yen/tree/main/reference), a host with `trimmedModules = true` evaluates
        only the ones it needs, about 400.

        The list is the closure of a learned core plus the options the host defines. It filters `module-list.nix` itself,
        so the order and the inline entries stay as they are, and the host passes it to `nixosSystem` as `baseModules`.
        You'll find the code in the host sink of
        [platforms/nixos.nix](https://github.com/vic/yen/blob/main/reference/modules/platforms/nixos.nix).
      ''
      (docs.table
        [ "Reference fleet: web-1, app-2 toplevel" "CPU" "Thunks" "GC total" ]
        [
          [
            "full list"
            "11.4 s"
            "14.57 M"
            "1.03 GB"
          ]
          [
            "trimmed list"
            "10.5 s"
            "13.21 M"
            "0.94 GB"
          ]
        ]
      )
      ''
        ## Three checks keep it honest

        - `modlist-same-drv`: each trimmed toplevel has the same `drvPath` as the full build.
        - `modlist-negative`: the list without nginx fails for a host that runs nginx, and the same list with nginx builds.
        - `cost.sh`: the trimmed eval uses at most 95% of the thunks.
      ''
      (docs.caution "One nixpkgs revision" ''
        A list belongs to one nixpkgs revision. After an update, `modlist-same-drv` fails until you compute the lists
        again, so only use this with that check running in CI.
      '')
      (docs.links [
        {
          title = "platforms/nixos.nix";
          href = "https://github.com/vic/yen/blob/main/reference/modules/platforms/nixos.nix";
          description = "The host sink: trimmed, full and own-pkgs builds.";
        }
        {
          title = "modlist research";
          href = "https://github.com/vic/yen/blob/main/vic/modlist-research.md";
          description = "How the lists are computed.";
        }
      ])
    ];
}
