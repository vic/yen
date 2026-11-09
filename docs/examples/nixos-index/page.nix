{
  title = "NixOS patterns";
  description = "What NixOS users write by hand in every multi-host flake, and how it looks in Yen. Each page is a tested template.";
  section = "nixos";
  order = 0;
  route = "nixos";

  body =
    { docs, pages, ... }:
    [
      ''
        These pages start from things NixOS users often ask about on [NixOS Discourse](https://discourse.nixos.org):
        a `mkHost` function, `specialArgs`, home-manager inside and outside NixOS, `allowUnfreePredicate`, and
        configuration that depends on your other hosts. Each page shows the code you'd usually write next to the Yen
        version, and its checks evaluate the real NixOS and home-manager configurations.
      ''
      (docs.links (
        map (p: {
          title = p.title;
          href = "/${p.route}/";
          inherit (p) description;
        }) (builtins.filter (p: p.section == "nixos" && p.route != "nixos") pages)
      ))
    ];
}
