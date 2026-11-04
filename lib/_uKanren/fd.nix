self:
let
  b = builtins;
  inherit (self._uKanren.core)
    andThen
    conj
    domOf
    inter
    post
    setDom
    sortInts
    unit
    ;
  inherit (self.uKanren) disj eq;
  # finite domains
  #: lib.uKanren.dom :: lvar -> [ int ] -> goal -- the variable takes one of these integers
  dom =
    x: ds: st:
    domMeet st x (sortInts ds) (domOf st x);
  # d: the new domain; cur: the domain x has, or null
  domMeet =
    st: x: d: cur:
    andThen (setDom st x (if cur == null then d else inter d cur)) post;
  #: lib.uKanren.infd :: [ lvar ] -> lo -> hi -> goal -- each variable takes an integer in lo..hi
  infd =
    xs: lo: hi:
    conj (map (x: dom x (b.genList (i: lo + i) (hi - lo + 1))) xs);
  #: lib.uKanren.propagator :: (state -> state or null) -> goal -- a finite-domain constraint, run again after every change
  propagator = c: st: andThen (c (st // { fdc = st.fdc ++ [ c ]; })) post;
  #: lib.uKanren.fdBound :: state -> [ lvar ] -> ([ domain ] -> state) -> state -- f on the domains, once every variable has one
  fdBound =
    st: xs: f:
    fdWith f st (map (domOf st) xs);
  fdWith =
    f: st: ds:
    if b.any (d: d == null) ds then st else f ds;
  #: lib.uKanren.minOf :: domain -> int -- the smallest value of a domain
  minOf = d: b.head d;
  #: lib.uKanren.maxOf :: domain -> int -- the largest value of a domain
  maxOf = d: b.elemAt d (b.length d - 1);
  #: lib.uKanren.lefd :: x -> y -> goal -- x <= y, by bounds propagation
  lefd =
    x: y: propagator (st: fdBound st [ x y ] (ds: lefdAt st x y (b.elemAt ds 0) (b.elemAt ds 1)));
  lefdAt =
    st: x: y: dx: dy:
    andThen (setDom st x (b.filter (v: v <= maxOf dy) dx)) (
      st2: setDom st2 y (b.filter (v: v >= minOf dx) dy)
    );
  #: lib.uKanren.ltfd :: x -> y -> goal -- x < y, by bounds propagation
  ltfd =
    x: y: propagator (st: fdBound st [ x y ] (ds: ltfdAt st x y (b.elemAt ds 0) (b.elemAt ds 1)));
  ltfdAt =
    st: x: y: dx: dy:
    andThen (setDom st x (b.filter (v: v < maxOf dy) dx)) (
      st2: setDom st2 y (b.filter (v: v > minOf dx) dy)
    );
  #: lib.uKanren.plusfd :: x -> y -> z -> goal -- x + y = z, by bounds propagation
  plusfd =
    x: y: z:
    propagator (
      st: fdBound st [ x y z ] (ds: plusfdAt st x y z (b.elemAt ds 0) (b.elemAt ds 1) (b.elemAt ds 2))
    );
  plusfdAt =
    st: x: y: z: dx: dy: dz:
    andThen (setDom st z (b.filter (v: v >= minOf dx + minOf dy && v <= maxOf dx + maxOf dy) dz)) (
      s1:
      andThen (setDom s1 x (b.filter (v: v >= minOf dz - maxOf dy && v <= maxOf dz - minOf dy) dx)) (
        s2: setDom s2 y (b.filter (v: v >= minOf dz - maxOf dx && v <= maxOf dz - minOf dx) dy)
      )
    );
  #: lib.uKanren.neqfd :: x -> y -> goal -- x != y over domains
  neqfd =
    x: y: propagator (st: fdBound st [ x y ] (ds: neqfdAt st x y (b.elemAt ds 0) (b.elemAt ds 1)));
  neqfdAt =
    st: x: y: dx: dy:
    if b.length dx == 1 && b.length dy == 1 then
      (if dx == dy then null else st)
    else if b.length dx == 1 then
      setDom st y (b.filter (v: v != b.head dx) dy)
    else if b.length dy == 1 then
      setDom st x (b.filter (v: v != b.head dy) dx)
    else
      st;
  #: lib.uKanren.distinctfd :: [ lvar ] -> goal -- every two variables differ
  distinctfd =
    xs:
    conj (
      b.concatLists (
        b.genList (
          i: map (y: neqfd (b.elemAt xs i) y) (b.genList (j: b.elemAt xs (i + j + 1)) (b.length xs - i - 1))
        ) (b.length xs)
      )
    );
  # enumerate: the variable with the smallest domain first; a variable with no domain stays as it is
  #: lib.uKanren.label :: [ lvar ] -> goal -- enumerate the values left in the domains, the smallest domain first
  label = xs: st: labelOpen xs st (b.filter (x: hasChoice (domOf st x)) xs);
  hasChoice = d: d != null && b.length d > 1;
  # open: the variables with a choice left; pick: the one with the smallest domain
  labelOpen =
    xs: st: open:
    if open == [ ] then
      unit st
    else
      labelPick xs st (
        b.foldl' (
          a: x: if a == null || b.length (domOf st x) < b.length (domOf st a) then x else a
        ) null open
      );
  labelPick =
    xs: st: pick:
    (disj (
      map (v: [
        (eq pick v)
        (label xs)
      ]) (domOf st pick)
    ))
      st;

in
{
  inherit
    dom
    infd
    propagator
    fdBound
    minOf
    maxOf
    lefd
    ltfd
    plusfd
    neqfd
    distinctfd
    label
    ;
}
