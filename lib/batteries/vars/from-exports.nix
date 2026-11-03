#: lib.batteries.vars.from-exports :: { holds; } -> key value -- one generator from-exports with the files of every generator an export carries to this scope; null when none
# the generators that exports carry (an export's `generators`, each with a `deploy` predicate) and that deploy here,
# as one generator `from-exports`; null when there are none. `holds` is the fleet's `yen.lib.holds`.
#   yen.aspects.generators-from-exports = { at = yen.kinds.host; generators = vars.from-exports { inherit holds; }; };
_:
{ holds }:
{ scope, exports, ... }:
let
  b = builtins;
  gens = b.concatMap (
    x: b.filter (g: holds g.deploy scope) (b.attrValues (x.value.generators or { }))
  ) exports;
in
if gens == [ ] then
  null
else
  {
    name = "from-exports";
    files = b.foldl' (a: g: a // g.files) { } gens;
  }
