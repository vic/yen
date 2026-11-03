# The style battery oracles: tests.style.<test> = { expr; expected; }. Run them: fastest --flake .#tests style
self:
let
  inherit (self.tests._batteries)
    b
    eq
    letsIn
    modulesIn
    nixUnder
    ;
in
{
  # #59: a kit or a template module has one top-level `let` (its bindings), never a nested one
  # and so has every module of a docs example and of the reference fleet (#59)
  one-let = eq (map toString (
    b.filter (f: letsIn f > 1) (
      nixUnder ../lib/kits
      ++ modulesIn ../templates
      ++ modulesIn ../docs/examples
      ++ nixUnder ../reference/modules
    )
  )) [ ];
}
