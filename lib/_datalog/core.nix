# The core of the Datalog engine: atom keys, sets, the keyed rules, the least model of negation-free rules and the reduct.
_:
let
  b = builtins;
  k = b.toJSON;
  index =
    xs:
    b.listToAttrs (
      map (x: {
        name = k x;
        value = x;
      }) xs
    );
  set = xs: b.mapAttrs (_: _: true) (index xs);
  # every atom once, in key order
  atomsOf =
    rules: b.attrValues (index (b.concatMap (r: [ r.head ] ++ r.pos or [ ] ++ r.neg or [ ]) rules));
  # rules with every atom as its key: the fixpoints below work on strings only
  keyed = map (r: {
    head = k r.head;
    pos = map k (r.pos or [ ]);
    neg = map k (r.neg or [ ]);
  });
  # least model of negation-free rules: pass over the rules until a pass adds nothing (at most one pass per rule)
  lmStep =
    rules: t:
    b.foldl' (
      t2: r:
      if t2 ? ${r.head} || !b.all (p: t2 ? ${p}) (r.pos or [ ]) then t2 else t2 // { ${r.head} = true; }
    ) t rules;
  lmFrom = rules: t: lmNext rules t (lmStep rules t);
  lmNext =
    rules: t: t2:
    if b.length (b.attrNames t2) == b.length (b.attrNames t) then t else lmFrom rules t2;
  lm = rules: lmFrom rules { };
  # Gelfond-Lifschitz reduct by the set i, then its least model
  gamma = rules: i: lm (b.filter (r: !b.any (n: i ? ${n}) (r.neg or [ ])) rules);
in
{
  inherit
    k
    index
    set
    atomsOf
    keyed
    lm
    gamma
    ;
}
