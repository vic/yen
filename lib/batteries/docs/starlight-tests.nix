#: lib.batteries.docs.starlight-tests :: { from; } -> out value -- the flake output `tests`, for github:denful/fastest
# The value of the `out` key of the sink `from`, which reduces by `merge` the tests that `starlight-page` and
# `starlight-links` give (`<page> = { fast; e2e; }`). It makes `tests.fast.<page>.<check>` and `tests.e2e.<page>.<check>`,
# each `{ expr; expected; }`.
#   yen.kinds.site.sinks.tests = { reduce = yen.lib.reduce.merge; out = starlight-tests { from = yen.kinds.site.sinks.tests; }; };
_:
{ from }:
{ sinks, ... }:
{
  tests = builtins.listToAttrs (
    map
      (k: {
        name = k;
        value = builtins.mapAttrs (_: t: t.${k}) sinks.${from.__sink};
      })
      [
        "fast"
        "e2e"
      ]
  );
}
