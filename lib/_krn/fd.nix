self:
let
  b = builtins;
  inherit (self._krn.core)
    andThen
    conj
    domOf
    inter
    post
    setDom
    sortInts
    unit
    ;
  inherit (self.krn) disj eq;
  # finite domains
  #: lib.krn.dom :: lvar -> [ int ] -> goal -- the variable takes one of these integers
  dom =
    x: ds: st:
    let
      cur = domOf st x;
      d = sortInts ds;
    in
    andThen (setDom st x (if cur == null then d else inter d cur)) post;
  #: lib.krn.infd :: [ lvar ] -> lo -> hi -> goal -- each variable takes an integer in lo..hi
  infd =
    xs: lo: hi:
    conj (map (x: dom x (b.genList (i: lo + i) (hi - lo + 1))) xs);
  #: lib.krn.propagator :: (state -> state or null) -> goal -- a finite-domain constraint, run again after every change
  propagator = c: st: andThen (c (st // { fdc = st.fdc ++ [ c ]; })) post;
  #: lib.krn.fdBound :: state -> [ lvar ] -> ([ domain ] -> state) -> state -- f on the domains, once every variable has one
  fdBound =
    st: xs: f:
    let
      ds = map (domOf st) xs;
    in
    if b.any (d: d == null) ds then st else f ds;
  #: lib.krn.minOf :: domain -> int -- the smallest value of a domain
  minOf = d: b.head d;
  #: lib.krn.maxOf :: domain -> int -- the largest value of a domain
  maxOf = d: b.elemAt d (b.length d - 1);
  #: lib.krn.lefd :: x -> y -> goal -- x <= y, by bounds propagation
  lefd =
    x: y:
    propagator (
      st:
      fdBound st [ x y ] (
        ds:
        let
          dx = b.elemAt ds 0;
          dy = b.elemAt ds 1;
        in
        andThen (setDom st x (b.filter (v: v <= maxOf dy) dx)) (
          st2: setDom st2 y (b.filter (v: v >= minOf dx) dy)
        )
      )
    );
  #: lib.krn.ltfd :: x -> y -> goal -- x < y, by bounds propagation
  ltfd =
    x: y:
    propagator (
      st:
      fdBound st [ x y ] (
        ds:
        let
          dx = b.elemAt ds 0;
          dy = b.elemAt ds 1;
        in
        andThen (setDom st x (b.filter (v: v < maxOf dy) dx)) (
          st2: setDom st2 y (b.filter (v: v > minOf dx) dy)
        )
      )
    );
  #: lib.krn.plusfd :: x -> y -> z -> goal -- x + y = z, by bounds propagation
  plusfd =
    x: y: z:
    propagator (
      st:
      fdBound st [ x y z ] (
        ds:
        let
          dx = b.elemAt ds 0;
          dy = b.elemAt ds 1;
          dz = b.elemAt ds 2;
        in
        andThen (setDom st z (b.filter (v: v >= minOf dx + minOf dy && v <= maxOf dx + maxOf dy) dz)) (
          s1:
          andThen (setDom s1 x (b.filter (v: v >= minOf dz - maxOf dy && v <= maxOf dz - minOf dy) dx)) (
            s2: setDom s2 y (b.filter (v: v >= minOf dz - maxOf dx && v <= maxOf dz - minOf dx) dy)
          )
        )
      )
    );
  #: lib.krn.neqfd :: x -> y -> goal -- x != y over domains
  neqfd =
    x: y:
    propagator (
      st:
      fdBound st [ x y ] (
        ds:
        let
          dx = b.elemAt ds 0;
          dy = b.elemAt ds 1;
        in
        if b.length dx == 1 && b.length dy == 1 then
          (if dx == dy then null else st)
        else if b.length dx == 1 then
          setDom st y (b.filter (v: v != b.head dx) dy)
        else if b.length dy == 1 then
          setDom st x (b.filter (v: v != b.head dy) dx)
        else
          st
      )
    );
  #: lib.krn.distinctfd :: [ lvar ] -> goal -- every two variables differ
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
  #: lib.krn.label :: [ lvar ] -> goal -- enumerate the values left in the domains, the smallest domain first
  label =
    xs: st:
    let
      open = b.filter (
        x:
        let
          d = domOf st x;
        in
        d != null && b.length d > 1
      ) xs;
      pick = b.foldl' (
        a: x: if a == null || b.length (domOf st x) < b.length (domOf st a) then x else a
      ) null open;
    in
    if open == [ ] then
      unit st
    else
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
