# uKanren: µKanren (Hemann, Friedman 2013) with constraints, in pure Nix. Builtins only.
#
# Terms: Nix values. A logic variable is { __lvar = n; }. Unification walks attrsets (same keys), Nix lists (same
# length) and scalars, with an occurs check. Relational lists are cons cells: `nil` and { head; tail; }, as in
# Scheme, so a list of unknown length can grow: `appendo` runs in every direction and enumerates without end.
#
# Constraints (miniKanren's =/= and cKanren's CLP(FD), Alvis et al. 2011):
#   neq u v        u and v never unify. Stored as the bindings that would make them equal; re-checked after each `eq`.
#   dom x [ ints ] x takes one of these integers. `infd xs lo hi` for a range.
#   lefd ltfd plusfd neqfd distinctfd   bounds propagation over domains, to a fixpoint after every change.
#   label xs       enumerate the values left in the domains (first-fail: the smallest domain first).
#
# A state is { s; c; neq; dom; fdc; }: substitution, next variable, disequality store, domains, FD propagators.
# The API is the parts in lib/_uKanren/: goals, finite domains, runs and relational lists, on the core of lib/_uKanren/core.nix.
self:
self._uKanren.goals
// self._uKanren.fd
// self._uKanren.run
// self._uKanren.lists
// {
  inherit (self._uKanren.core)
    var
    unify
    walkStar
    conj
    ;
}
