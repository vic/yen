# The explanations of the Datalog engine: why an atom holds, its proof tree, why it does not, and the verdict on a pair.
self:
let
  b = builtins;
  inherit (self._datalog.core) k set;
  inherit (self._datalog.certify) certifyRaw;
  # the rules that make an atom true in a model (one step of provenance); t and f are its true and false sets
  whyIn =
    rules: t: f: atom:
    b.filter (
      r: r.head == atom && b.all (p: t ? ${k p}) (r.pos or [ ]) && b.all (n: f ? ${k n}) (r.neg or [ ])
    ) rules;
  whyRaw =
    rules: model: atom:
    whyIn rules (set model.true) (set model.false) atom;
  # proof tree of a true atom: the rule its certificate gives it. Its positive atoms have smaller stages, so a proof
  # never cycles (D4). A non-true atom is { status = "false" | "undefined"; }
  ruleOfAtom =
    cert:
    b.listToAttrs (
      map (e: {
        name = k e.atom;
        value = e.rule;
      }) cert.true
    );
  proofIn =
    byRule: f: a:
    if byRule ? ${k a} then
      {
        atom = a;
        rule = byRule.${k a};
        pos = map (proofIn byRule f) (byRule.${k a}.pos or [ ]);
        neg = byRule.${k a}.neg or [ ];
      }
    else
      {
        atom = a;
        status = if f ? ${k a} then "false" else "undefined";
      };
  proofRaw =
    rules: model: atom:
    proofIn (ruleOfAtom (certifyRaw rules)) (set model.false) atom;
  # why an atom is not true: per rule with that head, the body atoms that stop it firing; t and u are the true and
  # undefined sets, rs the rules with that head
  whyNotIn =
    t: u: rs: atom:
    if t ? ${k atom} then
      [ ]
    else if rs == [ ] then
      [
        {
          rule = null;
          reason = "no rule has this head";
        }
      ]
    else
      map (r: {
        rule = r;
        missing = b.filter (p: !(t ? ${k p})) (r.pos or [ ]);
        blocking = b.filter (n: t ? ${k n}) (r.neg or [ ]);
        undefinedBody = b.filter (x: u ? ${k x}) ((r.pos or [ ]) ++ (r.neg or [ ]));
      }) rs;
  whyNotRaw =
    rules: model: atom:
    whyNotIn (set model.true) (set model.undefined) (b.filter (r: r.head == atom) rules) atom;
  # verdict on a pair of atoms (atomPos for, atomNeg against) in the well-founded model:
  #   "supported" atomPos true, atomNeg not true    "refuted" atomNeg true, atomPos not true
  #   "both"      both true                          "unknown" otherwise, if either is undefined
  #   "neither"   both false
  verdictOf =
    p: n: undefinedEither:
    if p && n then
      "both"
    else if p then
      "supported"
    else if n then
      "refuted"
    else if undefinedEither then
      "unknown"
    else
      "neither";
  judgeWith =
    w: atomPos: atomNeg:
    verdictOf (w.holds atomPos) (w.holds atomNeg) (
      b.elem atomPos w.undefined || b.elem atomNeg w.undefined
    );
in
{
  inherit
    whyRaw
    proofRaw
    whyNotRaw
    judgeWith
    ;
}
