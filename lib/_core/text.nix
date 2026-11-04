# Text and list helpers: substring search, the floor of routed elements, unique by key. builtins are global.
self:
let
  inherit (self._core.helpers) optional;
  inherit (builtins)
    any
    concatMap
    genericClosure
    intersectAttrs
    ;
  # n: the aspect an edge of origin "aspect <n>" comes from
  floorAt =
    labels: t: e: n:
    optional
      (builtins.substring 0 7 e.origin == "aspect " && labels ? ${n} && (labels.${n}.trust or 0) < t)
      (
        {
          edge = e;
          aspect = n;
          inherit (labels.${n}) trust file prefix;
        }
        // intersectAttrs { by = null; } labels.${n}
      );
in
{
  # s occurs in x, as text (no regex)
  hasInfix =
    s: x:
    any (i: builtins.substring i (builtins.stringLength s) x == s) (
      builtins.genList (i: i) (builtins.stringLength x + 1)
    );
  # the routed elements whose aspect's trust is below t; `labels` gives each aspect its label
  floorOf =
    labels: edges: t:
    concatMap (
      e: floorAt labels t e (builtins.substring 7 (builtins.stringLength e.origin) e.origin)
    ) edges;
  uniqueBy =
    key: xs:
    map (i: i.x) (genericClosure {
      startSet = map (x: {
        key = key x;
        inherit x;
      }) xs;
      operator = _: [ ];
    });
}
