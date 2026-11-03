self:
let
  b = builtins;
  inherit (self._krn.core)
    conj
    goal
    mplus
    post
    prefixOf
    unify
    unit
    var
    walkStar
    ;
  #: lib.krn.eq :: u -> v -> goal -- u and v unify
  eq =
    u: v: st:
    let
      s = unify st.s u v;
    in
    if s == null then null else post (st // { inherit s; });
  #: lib.krn.succeed :: goal -- the goal that holds once
  succeed = unit;
  #: lib.krn.fail :: goal -- the goal that never holds
  fail = _: null;
  #: lib.krn.disj :: [ goal ] -> goal -- one of the goals holds; the branches interleave
  disj = gs: st: { d = _: b.foldl' (acc: g: mplus acc (goal g st)) null gs; };
  #: lib.krn.conde :: [ [ goal ] ] -> goal -- one clause holds, each clause a conj
  conde = clauses: disj (map conj clauses);
  # fresh ({ a, b }: goals): one variable per formal argument. freshNamed [ "x" "y" ] (vs: goals): names from data.
  #: lib.krn.fresh :: ({ a, b, … }: goal) -> goal -- one new variable per formal argument
  fresh = f: freshNamed (b.attrNames (b.functionArgs f)) f;
  #: lib.krn.freshNamed :: [ name ] -> ({ name = lvar; } -> goal) -> goal -- one new variable per name, the names from data
  freshNamed =
    names: f: st:
    let
      vs = b.listToAttrs (
        b.genList (i: {
          name = b.elemAt names i;
          value = var (st.c + i);
        }) (b.length names)
      );
    in
    goal (f vs) (st // { c = st.c + b.length names; });
  #: lib.krn.project :: term -> (value -> goal) -> goal -- the goal from the current value of the term
  project =
    x: f: st:
    goal (f (walkStar st.s x)) st;

  # =/= : stored, so it holds whatever comes later
  #: lib.krn.neq :: u -> v -> goal -- u and v never unify, now or later
  neq =
    u: v: st:
    let
      s2 = unify st.s u v;
    in
    if s2 == null then
      unit st
    else
      let
        p = prefixOf st.s s2;
      in
      if p == { } then null else unit (st // { neq = st.neq ++ [ p ]; });

in
{
  inherit
    eq
    succeed
    fail
    disj
    conde
    fresh
    freshNamed
    project
    neq
    ;
}
