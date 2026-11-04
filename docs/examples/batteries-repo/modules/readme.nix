# README.md from sections in any file (ordered), with a notice in the file's comment syntax.
{ yen, ... }:
let
  inherit (yen.lib.batteries) files ordered;
in
{
  yen.kinds.repo.sinks.readme.reduce = ordered; # (1)
  yen.aspects.readme = {
    at = yen.kinds.repo;
    files = files.document {
      # (2)
      from = yen.kinds.repo.sinks.readme;
      path = "README.md";
    };
    readme = {
      name = "title";
      value = "# my repo\n${files.comment "README.md" "Generated. Run nix run .#write-files."}"; # (3)
    };
  };
  yen.aspects.readme-usage = {
    at = yen.kinds.repo;
    readme = {
      name = "usage";
      after = [ "title" ];
      value = "## Usage";
    };
  };
}
