{
  title = "Facts from other hosts";
  description = "known_hosts, WireGuard peers and Syncthing devices built from the other hosts, without reading nixosConfigurations.";
  section = "nixos";
  route = "nixos/cross-host";
  order = 4;

  body =
    { docs, ... }:
    [
      ''
        Some of a host's configuration is about the other hosts: SSH `knownHosts`, WireGuard peers, Syncthing devices,
        backup targets. People usually reach for one of these:

        - A hand-written list of hosts in a shared file, which goes out of date as soon as you add a host.
        - `self.nixosConfigurations.<other>.config` through `specialArgs`. When two hosts read derived values from each
          other, the evaluation can recurse forever.
        - The *collector [aspect](/behavior/aspects/)* from the
          [dendritic design guide](https://github.com/Doc-Steve/dendritic-design-with-flake-parts/wiki/Dendritic_Aspects),
          where each host feature adds its own device to a shared NixOS module. It works, but every host gets every
          contribution, including its own.

        In Yen a host's public facts are [fields](/model/kinds-fields/) of its instance. Here are three hosts and their facts:
      ''
      (docs.fileNoted "" "modules/fleet.nix")
      ''
        `(1)` declares the facts as fields of the `host` kind, and `(2)` gives each host its values.

        An aspect reads the other hosts through a tree request, which is one form of the [cycle](/behavior/cycle/):
      ''
      (docs.fileNoted "" "modules/mesh.nix")
      ''
        `(1)` is the tree request: every host, with its data. `(2)` is the `mesh` aspect, and at `(3)` it asks the tree
        for that request. The request is plain data, so nothing evaluates a NixOS system to read it, and
        [`stage`](/agents/stage/) can see the read.

        ## Facts only some hosts have

        A Syncthing device id only exists on hosts that run Syncthing. Each of them gives its id to the fleet's
        `syncthing-device` sink. A host has no such sink, so the id goes up to the fleet.
      ''
      (docs.fileNoted "" "modules/syncthing.nix")
      ''
        `(1)` is the fleet's sink. Its `reduce` is `elements`, which remembers who gave each id. `(2)` is a Syncthing
        host: it reads the sink as an arg and leaves out its own id. `(3)` is a host giving its id.
      ''
      (docs.note "Why there is no recursion" ''
        The hosts a tree request gives and the `syncthing-device` sink are Yen data, and they exist before any NixOS
        module runs. A NixOS module reads them, and never reads another host's NixOS `config`.
      '')
      (docs.tip "As a battery" ''
        This page writes the rule by hand, but the shape is ready-made as `yen.lib.batteries.mesh`: the records of a sink,
        minus your own. See [Generic batteries](/batteries/generic/). When it doesn't fit, keep your own copy of the lines above.
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
      hosts = eq (builtins.attrNames result.flake.nixosConfigurations) ([
        "desk"
        "laptop"
        "nas"
      ]);
      # fast: the peers the mesh aspect gives laptop, read from its NixOS module values with no NixOS eval
      peers =
        eq
          (builtins.concatMap (
            m: map (p: p.allowedIPs) (m.networking.wireguard.interfaces.wg0.peers or [ ])
          ) result.reduced.nixos."fleet:main/host:laptop")
          ([
            [ "10.9.0.2/32" ]
            [ "10.9.0.1/32" ]
          ]);
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
      c = n: flake.nixosConfigurations.${n}.config;
      peers = n: map (p: p.allowedIPs) (c n).networking.wireguard.interfaces.wg0.peers;
    in
    {
      known = eq (builtins.attrNames (c "desk").programs.ssh.knownHosts) ([
        "laptop"
        "nas"
      ]);
      peers = eq (peers "laptop") ([
        [ "10.9.0.2/32" ]
        [ "10.9.0.1/32" ]
      ]);
      syncthing = eq (builtins.attrNames (c "desk").services.syncthing.settings.devices) ([ "nas" ]);
      syncthing-nas = eq (builtins.attrNames (c "nas").services.syncthing.settings.devices) ([ "desk" ]);
      no-syncthing = no ((c "laptop").services.syncthing.enable);
    };
}
