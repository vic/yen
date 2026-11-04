# The certificate of the Datalog engine: the stages of the well-founded model, and the small trusted checker.
self:
let
  b = builtins;
  inherit (self._datalog.core)
    k
    index
    set
    atomsOf
    keyed
    lm
    ;
  # the prover: the stages of the well-founded model, I_{k+1} = W_P(I_k) (Van Gelder, Ross, Schlipf 1991, Def 3.4).
  # An atom's stage is the first k where it is decided: true by a rule whose body holds in I_k, false when it is in
  # the greatest unfounded set of I_k. A true atom carries a rule whose body was decided at smaller stages.
  # Undefined atoms are in neither list.
  firesIn = st: r: b.all (p: st.t ? ${p}) r.pos && b.all (n: st.f ? ${n}) r.neg;
  # what may still hold: the least model of the rules not blocked by I_k; the rest is unfounded
  mayIn =
    kr: st:
    lm (
      map (r: r // { neg = [ ]; }) (
        b.filter (r: !b.any (p: st.f ? ${p}) r.pos && !b.any (n: st.t ? ${n}) r.neg) kr
      )
    );
  stageAt =
    n: xs:
    b.listToAttrs (
      map (x: {
        name = x;
        value = n;
      }) xs
    );
  roundWith = st: tp: gus: {
    t = st.t // stageAt st.k tp;
    f = st.f // stageAt st.k gus;
    k = st.k + 1;
    done = tp == [ ] && gus == [ ];
  };
  round =
    kr: keys: st:
    roundWith st (b.filter (x: !(st.t ? ${x})) (map (r: r.head) (b.filter (firesIn st) kr))) (
      unfoundedAt keys st (mayIn kr st)
    );
  # the greatest unfounded set of I_k: the atoms not yet false that can no longer hold (`may` computed once per round)
  unfoundedAt =
    keys: st: may:
    b.filter (x: !(may ? ${x}) && !(st.f ? ${x})) keys;
  stagesFrom =
    kr: keys: st:
    stagesNext kr keys st (round kr keys st);
  stagesNext =
    kr: keys: st: n:
    if n.done then st else stagesFrom kr keys n;
  # the body of r was decided before stage s
  decidedBefore =
    final: s: r:
    b.all (p: (final.t.${p} or s) < s) r.pos && b.all (n: (final.f.${n} or s) < s) r.neg;
  # the first rule of the indexes is whose body was decided before s
  ruleAt =
    kr: final: s: is:
    b.head (b.filter (i: decidedBefore final s (b.elemAt kr i)) is);
  certifyWith = rules: kr: byKey: final: byHead: {
    true = map (x: {
      atom = byKey.${x};
      stage = final.t.${x};
      rule = b.elemAt rules (ruleAt kr final final.t.${x} byHead.${x});
    }) (b.attrNames final.t);
    false = map (x: {
      atom = byKey.${x};
      stage = final.f.${x};
    }) (b.attrNames final.f);
  };
  # the rules of each head, by index
  certifyKeyed =
    rules: kr: byKey:
    certifyWith rules kr byKey (stagesFrom kr (b.attrNames byKey) {
      t = { };
      f = { };
      k = 0;
    }) (b.groupBy (i: (b.elemAt kr i).head) (b.genList (i: i) (b.length kr)));
  certifyRaw = rules: certifyKeyed rules (keyed rules) (index (atomsOf rules));
  # the trusted checker, small and plain: a certificate is valid when each true atom has a rule of the program whose
  # positive atoms are true and negative atoms false at smaller stages, and every rule of a false atom has a positive
  # atom false at a stage no later, or a negative atom true at a smaller stage. Sound by induction on the stage (VRS
  # 1991, Thm 5.4); no stratification needed. True and false are disjoint without a check: an atom in both has a rule
  # whose blocking atom is also in both with a smaller sum of its two stages, and the sum cannot descend forever.
  # Both are proved in Lean: lean/Certificate.lean (`sound`, `disjoint`), checked by `lean-check` in CI.
  norm = r: {
    inherit (r) head;
    pos = r.pos or [ ];
    neg = r.neg or [ ];
  };
  stagesOf =
    es:
    b.listToAttrs (
      map (e: {
        name = k e.atom;
        value = e.stage;
      }) es
    );
  before =
    m: s: x:
    m ? ${k x} && m.${k x} < s;
  notAfter =
    m: s: x:
    m ? ${k x} && m.${k x} <= s;
  supportedIn =
    program: T: U: e:
    program ? ${k (norm e.rule)}
    && k e.rule.head == k e.atom
    && b.all (before T e.stage) (e.rule.pos or [ ])
    && b.all (before U e.stage) (e.rule.neg or [ ]);
  unfoundedIn =
    byHead: T: U: e:
    b.all (r: b.any (notAfter U e.stage) r.pos || b.any (before T e.stage) r.neg) (
      byHead.${k e.atom} or [ ]
    );
  checkWith = cert: program: byHead: T: U: {
    valid = b.all (supportedIn program T U) cert.true && b.all (unfoundedIn byHead T U) cert.false;
  };
  checkRaw =
    rules: cert:
    checkWith cert (set (map norm rules)) (b.groupBy (r: k r.head) (
      map norm rules
    )) (stagesOf cert.true) (stagesOf cert.false);
in
{
  inherit certifyRaw checkRaw;
}
