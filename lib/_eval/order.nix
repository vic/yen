# An eval part: order: a sink every scope has; first answer, else 0. Siblings sort by (order, key); a parent sorts first
# A part is `_: st:`; `st` is the state of one eval: the names of every part, `root`, and the base helpers.
_: st:
let
  inherit (st)
    active
    all
    aspectNames
    aspects
    b
    byScope
    concatMap
    errWith
    filter
    foldl'
    groupBy
    outAt
    parentId
    toList
    unsorted
    ;
  # ── order: a sink every scope has; first answer, else 0. Siblings sort by (order, key); a parent sorts first ──
  orderNames = filter (n: aspects.${n} ? order || aspects.${n} ? cycle) aspectNames; # only these can answer `order`
  ordersAt =
    s:
    concatMap (
      n:
      if !active.${n}.${s.id} then
        [ ]
      else
        toList (aspects.${n}.order or [ ]) ++ toList ((outAt n s).order or [ ])
    ) orderNames;
  isNum = o: b.isInt o || b.isFloat o;
  orderErrors = map (s: errWith s.id "order is not a number" { code = "order"; }) (
    filter (s: !all isNum (ordersAt s)) unsorted
  );
  sortKeys = byScope (
    s:
    (if s.parent == null then [ ] else sortKeys.${s.parent.id})
    ++ [
      [
        (b.head (filter isNum (ordersAt s) ++ [ 0 ]))
        s.key
      ]
    ]
  ) unsorted;
  scopes =
    b.seq (foldl' (_: s: sortKeys.${s.id}) null unsorted) # force keys breadth first: no deep thunk chain
      (b.sort (x: y: sortKeys.${x.id} < sortKeys.${y.id}) unsorted);
  childrenAt = groupBy parentId scopes;

in
{
  inherit
    orderNames
    ordersAt
    isNum
    orderErrors
    sortKeys
    scopes
    childrenAt
    ;
}
