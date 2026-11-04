# Ground Datalog with negation. A rule is { head; pos ? [ ]; neg ? [ ]; }: head holds when every pos atom holds and
# no neg atom holds. An atom is any JSON value (a string, or a tuple `[ rel t… ]`), keyed by `toJSON`.
# Semantics: the well-founded model (Van Gelder, Ross, Schlipf 1991), by the alternating fixpoint: three values,
# total, no strata needed. `stable` gives the stable models (Gelfond, Lifschitz 1988) for choice: 2^|undefined|.
# Builtins only.
self:
let
  inherit (self._datalog.ground)
    isVar
    comparisons
    atom
    rule
    groundWithRaw
    ;
  inherit (self._datalog.wfs) byAtom wfsRaw stableRaw;
  inherit (self._datalog.certify) certifyRaw checkRaw;
  inherit (self._datalog.explain)
    whyRaw
    proofRaw
    whyNotRaw
    judgeWith
    ;
in
# the same functions, on literals: rules, atoms and model lookups normalized once at the entry
{
  inherit isVar comparisons;
  #: lib.datalog.atom :: literal -> atom -- the atom of a literal, its instance terms as { kind; name; }
  inherit atom;
  # ground instances of range-restricted rules over tuple facts: every instance whose positive atoms may hold.
  # The rest can never fire, so the well-founded model is the same. External atoms (ext: name -> terms -> bool) are
  # decided, then dropped. `faults`: the external atoms whose answer was not a bool
  #: lib.datalog.groundWith :: { name = terms -> bool; } -> [ rule ] -> [ atom ] -> { rules; faults; } -- the ground instances whose positive atoms may hold; external atoms decided, then dropped
  groundWith =
    ext: rules: facts:
    groundWithRaw ext (map rule rules) (map atom facts);
  #: lib.datalog.ground :: [ rule ] -> [ atom ] -> [ rule ] -- groundWith the comparisons
  ground = rules: facts: (groundWithRaw comparisons (map rule rules) (map atom facts)).rules;
  #: lib.datalog.wfs :: [ rule ] -> { true; undefined; false; holds; } -- the well-founded model of ground rules (three values)
  wfs = rules: byAtom (wfsRaw (map rule rules));
  #: lib.datalog.stable :: [ rule ] -> [ [ atom ] ] -- the stable models, each a sorted list of true atoms
  stable = rules: stableRaw (map rule rules);
  #: lib.datalog.why :: [ rule ] -> model -> atom -> [ rule ] -- the rules that make the atom true in the model
  why =
    rules: model: a:
    whyRaw (map rule rules) model (atom a);
  #: lib.datalog.proof :: [ rule ] -> model -> atom -> tree -- the proof tree of a true atom; { status; } for a false or undefined one
  proof =
    rules: model: a:
    proofRaw (map rule rules) model (atom a);
  #: lib.datalog.certify :: [ rule ] -> { true = [ { atom; stage; rule; } ]; false = [ { atom; stage; } ]; } -- the stages of the well-founded model, a certificate of each decided atom
  certify = rules: certifyRaw (map rule rules);
  #: lib.datalog.checkCertificate :: [ rule ] -> certificate -> { valid; } -- the small trusted checker of a certificate
  checkCertificate = rules: checkRaw (map rule rules);
  #: lib.datalog.whyNot :: [ rule ] -> model -> atom -> [ { rule; missing; blocking; undefinedBody; } ] -- per rule with that head, the body atoms that stop it
  whyNot =
    rules: model: a:
    whyNotRaw (map rule rules) model (atom a);
  #: lib.datalog.judge :: [ rule ] -> atomFor -> atomAgainst -> string -- "supported", "refuted", "both", "neither" or "unknown" in the well-founded model
  judge =
    rules: p: n:
    judgeWith (wfsRaw (map rule rules)) (atom p) (atom n);
  # facts: atoms with no body
  #: lib.datalog.facts :: [ atom ] -> [ rule ] -- each atom as a rule with no body
  facts = as: map (a: { head = atom a; }) as;
}
