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
      e:
      let
        n = builtins.substring 7 (builtins.stringLength e.origin) e.origin;
        l = labels.${n};
      in
      optional (builtins.substring 0 7 e.origin == "aspect " && labels ? ${n} && (l.trust or 0) < t) (
        {
          edge = e;
          aspect = n;
          inherit (l) trust file prefix;
        }
        // intersectAttrs { by = null; } l
      )
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
