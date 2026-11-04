self:
let
  b = builtins;
  inherit (self._uKanren.core)
    conj
    goal
    mplus
    post
    prefixOf
    unify
    unit
    var
    varsFrom
    walkStar
    ;
  #: lib.uKanren.eq :: u -> v -> goal -- u and v unify
  eq =
    u: v: st:
    eqWith st (unify st.s u v);
  eqWith = st: s: if s == null then null else post (st // { inherit s; });
  #: lib.uKanren.succeed :: goal -- the goal that holds once
  succeed = unit;
  #: lib.uKanren.fail :: goal -- the goal that never holds
  fail = _: null;
  #: lib.uKanren.disj :: [ goal ] -> goal -- one of the goals holds; the branches interleave
  disj = gs: st: { d = _: b.foldl' (acc: g: mplus acc (goal g st)) null gs; };
  #: lib.uKanren.conde :: [ [ goal ] ] -> goal -- one clause holds, each clause a conj
  conde = clauses: disj (map conj clauses);
  # fresh ({ a, b }: goals): one variable per formal argument. freshNamed [ "x" "y" ] (vs: goals): names from data.
  #: lib.uKanren.fresh :: ({ a, b, … }: goal) -> goal -- one new variable per formal argument
  fresh = f: freshNamed (b.attrNames (b.functionArgs f)) f;
  #: lib.uKanren.freshNamed :: [ name ] -> ({ name = lvar; } -> goal) -> goal -- one new variable per name, the names from data
  freshNamed =
    names: f: st:
    goal (f (varsFrom st.c names)) (st // { c = st.c + b.length names; });
  #: lib.uKanren.project :: term -> (value -> goal) -> goal -- the goal from the current value of the term
  project =
    x: f: st:
    goal (f (walkStar st.s x)) st;

  # =/= : stored, so it holds whatever comes later
  #: lib.uKanren.neq :: u -> v -> goal -- u and v never unify, now or later
  neq =
    u: v: st:
    neqWith st (unify st.s u v);
  # s2: the substitution with u and v made equal, or null
  neqWith = st: s2: if s2 == null then unit st else neqStore st (prefixOf st.s s2);
  neqStore = st: p: if p == { } then null else unit (st // { neq = st.neq ++ [ p ]; });

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
