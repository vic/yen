# The well-founded model of the Datalog engine (alternating fixpoint) and its stable models.
self:
let
  b = builtins;
  inherit (self._datalog.core)
    k
    set
    atomsOf
    keyed
    gamma
    ;
  inherit (self._datalog.ground) atom;
  byAtom = m: m // { holds = a: m.holds (atom a); };
  # lfp of gamma²: it grows from the empty set, so it stops when a round adds nothing
  lfpFrom = kr: a: lfpNext kr a (gamma kr (gamma kr a));
  lfpNext =
    kr: a: a2:
    if b.length (b.attrNames a2) == b.length (b.attrNames a) then a else lfpFrom kr a2;
  # the model from t, the true atoms, and g, what may hold
  modelOf = atoms: t: g: {
    true = b.filter (a: t ? ${k a}) atoms;
    undefined = b.filter (a: g ? ${k a} && !(t ? ${k a})) atoms;
    false = b.filter (a: !(g ? ${k a})) atoms;
    holds = a: t ? ${k a};
  };
  wfsWith =
    atoms: kr: t:
    modelOf atoms t (gamma kr t);
  wfsKeyed = atoms: kr: wfsWith atoms kr (lfpFrom kr { });
  wfsRaw = rules: wfsKeyed (atomsOf rules) (keyed rules);
  # the stable models: the true atoms plus each subset of the undefined ones that reproduces itself
  subsetsOf = b.foldl' (acc: x: acc ++ map (s: s ++ [ x ]) acc) [ [ ] ];
  reproduces = kr: s: b.attrNames (gamma kr s) == b.attrNames s;
  stableIn =
    kr: w:
    b.filter (m: reproduces kr (set m)) (
      map (s: b.sort (x: y: k x < k y) (w.true ++ s)) (subsetsOf w.undefined)
    );
  stableRaw = rules: stableIn (keyed rules) (wfsRaw rules);
in
{
  inherit byAtom wfsRaw stableRaw;
}
