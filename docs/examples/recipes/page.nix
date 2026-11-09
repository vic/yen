{
  title = "All recipes";
  description = "Complete fleets for common jobs, from simple to advanced. Each one is a template you can copy.";
  section = "recipes";
  order = 0;
  route = "recipes";

  body =
    { docs, pages, ... }:
    [
      ''
        Each recipe is a complete flake template, and it is tested. Read the page, copy the template and make it yours.
        They go from simple to advanced, so start at the top.
      ''
      (docs.links (
        map (p: {
          title = p.title;
          href = "/${p.route}/";
          inherit (p) description;
        }) (builtins.filter (p: p.section == "recipes" && p.route != "recipes") pages)
      ))
    ];
}
