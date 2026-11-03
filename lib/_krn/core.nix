# The core of krn: terms, unification, the constraint store, states and streams. The API parts in lib/_krn/ read it.
_:
let
  b = builtins;
  isVar = x: b.isAttrs x && x ? __lvar;
  #: lib.krn.var :: int -> lvar -- the logic variable number n
  var = n: { __lvar = n; };
  isData = x: b.isAttrs x && !b.isFunction x && !(x ? __lvar);
  key = v: toString v.__lvar;
  walk = s: x: if isVar x && s ? ${key x} then walk s s.${key x} else x;
  occurs =
    s: v: x:
    let
      y = walk s x;
    in
    if isVar y then
      y.__lvar == v.__lvar
    else if b.isList y then
      b.any (occurs s v) y
    else if isData y then
      b.any (k: occurs s v y.${k}) (b.attrNames y)
    else
      false;
  ext =
    s: v: x:
    if occurs s v x then null else s // { ${key v} = x; };
  #: lib.krn.unify :: subst -> u -> v -> subst or null -- the substitution extended so u and v are equal, with an occurs check; null when they cannot be
  unify =
    s: u: v:
    let
      x = walk s u;
      y = walk s v;
    in
    if s == null then
      null
    else if isVar x && isVar y && x.__lvar == y.__lvar then
      s
    else if isVar x then
      ext s x y
    else if isVar y then
      ext s y x
    else if b.isList x && b.isList y then
      (
        if b.length x != b.length y then
          null
        else
          b.foldl' (acc: i: if acc == null then null else unify acc (b.elemAt x i) (b.elemAt y i)) s (
            b.genList (i: i) (b.length x)
          )
      )
    else if isData x && isData y then
      (
        if b.attrNames x != b.attrNames y then
          null
        else
          b.foldl' (acc: k: if acc == null then null else unify acc x.${k} y.${k}) s (b.attrNames x)
      )
    else if x == y then
      s
    else
      null;

  # ── constraint store ──
  andThen = st: f: if st == null then null else f st;
  # the bindings unify added: a disequality is violated exactly when all of them hold
  prefixOf = s: s2: removeAttrs s2 (b.attrNames s);
  recheckNeq =
    st:
    b.foldl' (
      acc: p:
      andThen acc (
        a:
        let
          s2 = b.foldl' (s: k: unify s (var (b.fromJSON k)) p.${k}) a.s (b.attrNames p);
        in
        if s2 == null then
          a # can never be equal: drop it
        else
          let
            p2 = prefixOf a.s s2;
          in
          if p2 == { } then null else a // { neq = a.neq ++ [ p2 ]; }
      )
    ) (st // { neq = [ ]; }) st.neq;
  sortInts = b.sort b.lessThan;
  inter = d1: d2: b.filter (v: b.elem v d2) d1;
  # a variable's domain: [ v ] when it is bound to an integer, null when it has none
  domOf =
    st: x:
    let
      w = walk st.s x;
    in
    if b.isInt w then
      [ w ]
    else if isVar w then
      st.dom.${key w} or null
    else
      [ ];
  setDom =
    st: x: d:
    let
      w = walk st.s x;
    in
    if d == [ ] then
      null
    else if b.isInt w then
      (if b.elem w d then st else null)
    else if isVar w then
      (
        if b.length d == 1 then
          (
            let
              s2 = unify st.s w (b.head d);
            in
            if s2 == null then
              null
            else
              st
              // {
                s = s2;
                dom = removeAttrs st.dom [ (key w) ];
              }
          )
        else
          st
          // {
            dom = st.dom // {
              ${key w} = d;
            };
          }
      )
    else
      null;
  # bound variables leave the domain table; two domain variables unified meet
  recheckDom =
    st:
    b.foldl' (
      acc: n:
      andThen acc (
        a:
        if !(a.dom ? ${n}) then
          a
        else
          let
            d = a.dom.${n};
            w = walk a.s (var (b.fromJSON n));
            rest = a // {
              dom = removeAttrs a.dom [ n ];
            };
          in
          if b.isInt w then
            (if b.elem w d then rest else null)
          else if isVar w && key w != n then
            setDom rest w (if rest.dom ? ${key w} then inter d rest.dom.${key w} else d)
          else if isVar w then
            a
          else
            null
      )
    ) st (b.attrNames st.dom);
  step = st: b.foldl' (acc: c: andThen acc c) (andThen (recheckNeq st) recheckDom) st.fdc;
  # run every check until nothing changes (bounded: each round removes a value or binds a variable)
  settle =
    st:
    let
      go =
        n: a:
        if a == null || n == 0 then
          a
        else
          let
            a2 = step a;
          in
          if a2 == null then
            null
          else if a2.s == a.s && a2.dom == a.dom && a2.neq == a.neq then
            a2
          else
            go (n - 1) a2;
    in
    go 1000 st;
  unit = st: {
    h = st;
    t = null;
  };
  post =
    st:
    let
      r = settle st;
    in
    if r == null then null else unit r;

  mplus =
    s1: s2:
    if s1 == null then
      s2
    else if s1 ? d then
      { d = _: mplus s2 (s1.d null); }
    else
      {
        h = s1.h;
        t = mplus s1.t s2;
      };
  bind =
    s: g:
    if s == null then
      null
    else if s ? d then
      { d = _: bind (s.d null) g; }
    else
      mplus (g s.h) (bind s.t g);
  take =
    n: s:
    if n == 0 || s == null then
      [ ]
    else if s ? d then
      take n (s.d null)
    else
      [ s.h ] ++ take (n - 1) s.t;
  takeAll =
    s:
    if s == null then
      [ ]
    else if s ? d then
      takeAll (s.d null)
    else
      [ s.h ] ++ takeAll s.t;
  # fuel-bounded take: forcing a suspension or yielding a cell costs 1. n < 0 means no limit.
  # complete only when the stream ended or n answers were taken.
  takeFuel =
    n: fuel: s:
    if n == 0 || s == null then
      {
        answers = [ ];
        complete = true;
      }
    else if fuel <= 0 then
      {
        answers = [ ];
        complete = false;
      }
    else if s ? d then
      takeFuel n (fuel - 1) (s.d null)
    else
      let
        r = takeFuel (n - 1) (fuel - 1) s.t;
      in
      r // { answers = [ s.h ] ++ r.answers; };
  goal = g: if b.isList g then conj g else g;
  #: lib.krn.conj :: [ goal ] -> goal -- all goals hold (a list of goals is a conj too)
  conj = gs: st: b.foldl' (acc: g: bind acc (goal g)) (unit st) gs;

  #: lib.krn.walkStar :: subst -> term -> term -- the term with every bound variable replaced, deeply
  walkStar =
    s: x:
    let
      y = walk s x;
    in
    if b.isList y then
      map (walkStar s) y
    else if isData y then
      b.mapAttrs (_: walkStar s) y
    else
      y;
  varsOf =
    x:
    if isVar x then
      [ x.__lvar ]
    else if b.isList x then
      b.concatMap varsOf x
    else if isData x then
      b.concatMap (k: varsOf x.${k}) (b.attrNames x)
    else
      [ ];
  namesFor =
    x:
    let
      vs = b.foldl' (acc: v: if b.elem v acc then acc else acc ++ [ v ]) [ ] (varsOf x);
    in
    b.listToAttrs (
      b.genList (i: {
        name = toString (b.elemAt vs i);
        value = "_.${toString i}";
      }) (b.length vs)
    );
  rename =
    names: y:
    if isVar y then
      names.${key y} or "_.?"
    else if b.isList y then
      map (rename names) y
    else if isData y then
      b.mapAttrs (_: rename names) y
    else
      y;
  reify = x: rename (namesFor x) x;
  start =
    f:
    goal (f (var 0)) {
      s = { };
      c = 1;
      neq = [ ];
      dom = { };
      fdc = [ ];
    };
  answer = st: reify (walkStar st.s (var 0));
  # the answer with the constraints left on its fresh variables
  answerC =
    st:
    let
      v = walkStar st.s (var 0);
      mine = n: (namesFor v) ? ${n};
      neqs = b.filter (p: b.all mine (b.attrNames p)) (map (p: b.mapAttrs (_: walkStar st.s) p) st.neq);
      names = namesFor [
        v
        (map (
          p:
          map (k: [
            (var (b.fromJSON k))
            p.${k}
          ]) (b.attrNames p)
        ) neqs)
      ]; # answer variables first, then the ones only constraints name
    in
    {
      value = rename names v;
      neq = map (
        p:
        map (k: [
          names.${k}
          (rename names p.${k})
        ]) (b.attrNames p)
      ) neqs;
      dom = b.listToAttrs (
        map (n: {
          name = names.${n};
          value = st.dom.${n};
        }) (b.filter mine (b.attrNames st.dom))
      );
    };
in
{
  inherit
    andThen
    answer
    answerC
    b
    bind
    conj
    domOf
    ext
    goal
    inter
    isData
    isVar
    key
    mplus
    namesFor
    occurs
    post
    prefixOf
    recheckDom
    recheckNeq
    reify
    rename
    setDom
    settle
    sortInts
    start
    step
    take
    takeAll
    takeFuel
    unify
    unit
    var
    varsOf
    walk
    walkStar
    ;
}
