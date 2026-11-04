# Fonts are a system concern on NixOS, and a home concern where there is no NixOS. `at` decides, not mkIf.
{ yen, ... }:
{
  yen.aspects.fonts-system = {
    at = yen.kinds.host; # (1)
    nixos =
      { pkgs, ... }:
      {
        fonts.packages = [ pkgs.inter ];
      };
  };
  yen.aspects.fonts-home = {
    at = yen.kinds.home; # (2)
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.inter ];
        fonts.fontconfig.enable = true;
      };
  };
}
