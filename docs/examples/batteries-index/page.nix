{
  title = "Battery packs";
  description = "Ready rules for common jobs, in yen.lib.batteries. You write every key; a battery is the value. Or write your own.";
  section = "batteries";
  order = 0;
  route = "batteries";

  body =
    { docs, pages, ... }:
    [
      ''
        The yen engine is domain independent: it knows no host, no user and no NixOS. The examples in these docs write
        every rule by hand, so you can see each step. Many rules come back in every fleet.
        A battery is such a rule, ready to use, as a plain Nix value. This is how a fleet uses two of them:
      ''
      (docs.nix ''
        yen.kinds.host.sinks.unfree.nixos = yen.lib.batteries.nixos.unfree { from = yen.kinds.host.sinks.unfree; };
        yen.aspects.hostname = { at = yen.kinds.host; nixos = yen.lib.batteries.nixos.hostname; };
      '')
      ''
        You write `yen.kinds.…`, the [sinks](/behavior/sinks/) and the [aspects](/behavior/aspects/) with your own names. The battery is the value of one key.
        Above, `unfree` is the value of the `nixos` key of a sink, and `hostname` is the value of the `nixos` key of an aspect.
        A battery adds no word to your fleet. It reads only `scope` and `sinks`, and it takes the sinks it reads
        as refs, so it works in any fleet.

        `yen.lib.batteries` has two kinds of battery:

        - Generic batteries, at the top, know no domain: `mesh`, `claim`, `ordered`. See [Generic batteries](/batteries/generic/).
        - A pack is the batteries of one domain, under its name: `yen.lib.batteries.nixos`. See [NixOS batteries](/batteries/nixos/).

        When a battery does not fit, write your own with the same shape. It is a few lines of Nix in your fleet:
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
