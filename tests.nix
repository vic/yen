# yen's test suites, for github:denful/fastest: tests.<suite>.<test> = { expr; expected; }.
# The fixpoint of default.nix with the leaves of tests/ added at the path `tests`, so a suite reads yen's private
# parts from `self`. A file directly in tests/ is a suite; a file starting with `_` and the subdirectories (fixtures,
# cost cases) are parts the suites share.
let
  b = builtins;
  inherit (import ./.) loader;
  self = loader.unite loader.self (loader.leavesOf [ "tests" ] ./tests) self;
  isSuite = n: (b.readDir ./tests).${n} == "regular" && b.match "[^_].*\\.nix" n != null;
in
b.listToAttrs (
  map (n: {
    name = loader.stem n;
    value = self.tests.${loader.stem n};
  }) (b.filter isSuite (b.attrNames (b.readDir ./tests)))
)
