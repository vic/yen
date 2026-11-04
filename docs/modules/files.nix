# The pages and the sidebar are built from docs/examples (write-files), never committed (#91): docs-build and docs-dev write
# them first. README, CONTRIBUTING and the workflows are committed, and each gets a check: the committed file must match.
{
  yen,
  lib,
  inputs,
  ...
}:
{
  yen.kinds.site.sinks.files.out = yen.lib.batteries.files.writer {
    from = yen.kinds.site.sinks.files;
    inherit (inputs) files;
    inherit lib;
    pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
    root = inputs.self;
    relativeRoot = "docs";
    # the site pages and sidebar: a build output, not a source
    unchecked = p: lib.hasPrefix "src/content/docs/" p || p == "src/sidebar.json";
  };
}
