# The reference template's test suites as a flake output, for github:denful/fastest (parallel, pure):
#   nix run github:denful/fastest#fastest -- --flake .#tests reference
{ yen, inputs, ... }:
{
  yen.aspects.test-suites = {
    at = yen.kinds.fleet;
    out =
      { ... }:
      {
        tests = (import ../../tests.nix { inherit inputs; }).tests;
      };
  };
}
