{
  title = "Battery packs";
  description = "Ready-made rules for common jobs, in yen.lib.batteries. You write the keys and a battery is the value. Or write your own.";
  section = "batteries";
  order = 0;
  route = "batteries";

  body =
    { docs, pages, ... }:
    [
      ''
        The Yen engine doesn't know about any domain: no hosts, no users, no NixOS. The examples in these docs write every
        rule by hand so you can see each step, but many of those rules show up in every fleet. A battery is one of them,
        ready to use as a plain Nix value. Here is a fleet using two:
      ''
      (docs.nix ''
        yen.kinds.host.sinks.unfree.nixos = yen.lib.batteries.nixos.unfree { from = yen.kinds.host.sinks.unfree; };
        yen.aspects.hostname = { at = yen.kinds.host; nixos = yen.lib.batteries.nixos.hostname; };
      '')
      ''
        You write `yen.kinds.…`, the [sinks](/behavior/sinks/) and the [aspects](/behavior/aspects/), with your own names,
        and the battery is the value of one key. Above, `unfree` is the value of a sink's `nixos` key, and `hostname` is
        the value of an aspect's `nixos` key. A battery never adds a name to your fleet. It reads only `scope` and
        `sinks`, and it takes the sinks it reads as refs, so it works in any fleet.

        `yen.lib.batteries` holds two kinds:

        - Generic batteries sit at the top and know no domain: `mesh`, `claim`, `ordered`. See [Generic batteries](/batteries/generic/).
        - A pack groups the batteries of one domain under its name, like `yen.lib.batteries.nixos`. See [NixOS batteries](/batteries/nixos/).

        When no battery fits, write your own in the same shape. It's a few lines of Nix in your fleet, see
        [Write your own](/batteries/generic/#write-your-own). The packs:
      ''
      (docs.links (
        map (p: {
          title = p.title;
          href = "/${p.route}/";
          inherit (p) description;
        }) (builtins.filter (p: p.section == "batteries" && p.route != "batteries") pages)
      ))
    ];
}
