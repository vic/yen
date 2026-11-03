# An eval part: cycles: one per (aspect, scope). Its own tree requests feed its sources
# A part is `_: st:`; `st` is the state of one eval: the names of every part, `root`, and the base helpers.
_: st:
let
  inherit (st)
    active
    aspectNames
    aspects
    b
    byScope
    filter
    mapAttrs
    sourcesAt
    unsorted
    ;
  # ── cycles: one per (aspect, scope). Its own tree requests feed its sources ──
  cycleOuts = mapAttrs (
    n: a:
    byScope (
      s:
      let
        o = a.cycle (sourcesAt s (o.tree or [ ]));
      in
      o
    ) (filter (s: active.${n}.${s.id}) unsorted)
  ) (b.removeAttrs aspects (filter (n: !(aspects.${n} ? cycle)) aspectNames));
  outAt = n: s: cycleOuts.${n}.${s.id} or { };

in
{
  inherit
    cycleOuts
    outAt
    ;
}
