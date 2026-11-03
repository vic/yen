# Every example with a flake.nix is a flake template (yen.lib.batteries.docs.templates), and so is every user project
# under templates/. Pure and cheap: no inputs, no yen evaluation. Both flakes use it: docs/flake.nix and the
# repository root flake.nix. reference is the showcase template: its yen input is the repository itself.
let
  templates = (import ../.).lib.batteries.docs.templates;
in
templates {
  root = ./examples;
  description = d: (import (d + "/page.nix")).description;
}
// templates {
  root = ../templates;
  description = d: (import (d + "/flake.nix")).description;
}
