# The grounder of the Datalog engine: variables, comparisons, joins over indexed tuples, and atom and rule normalization.
self:
let
  b = builtins;
  inherit (self._datalog.core) k index;
  # ── the grounder: a variable is { var = "X"; }, every other term a constant (int, string, bool) ──
  #: lib.datalog.isVar :: term -> bool -- the term is a variable { var = "X"; }
  isVar = t: b.isAttrs t && t ? var;
  # externals decide an atom on bound terms with a function: never a fact, never a head. The comparisons are built in;
  # they hold on terms of one type
  ltOf = x: y: (b.isInt x && b.isInt y || b.isString x && b.isString y) && x < y;
  comparisons = {
    #: lib.datalog.comparisons.neq :: [ a b ] -> bool -- the two bound terms differ
    neq = ts: b.elemAt ts 0 != b.elemAt ts 1;
    #: lib.datalog.comparisons.lt :: [ a b ] -> bool -- a < b, for two ints or two strings; false on terms of two types
    lt = ts: ltOf (b.elemAt ts 0) (b.elemAt ts 1);
  };
  bind =
    s: t: v:
    if isVar t then
      (
        if !(s ? ${t.var}) then
          s // { ${t.var} = v; }
        else if s.${t.var} == v then
          s
        else
          null
      )
    else if t == v then
      s
    else
      null;
  unify =
    s: atom: tuple:
    if b.length atom != b.length tuple then
      null
    else
      b.foldl' (acc: i: if acc == null then null else bind acc (b.elemAt atom i) (b.elemAt tuple i)) s (
        b.genList (i: i) (b.length atom)
      );
  sub = s: map (t: if isVar t then s.${t.var} else t);
  # an external atom's answer on the bound terms: true, false, or anything else, which is a fault
  call =
    ext: s: a:
    ext.${b.head a} (b.tail (sub s a));
  # the bindings of r's positive atoms (externals aside) over idx (relation -> tuples), left to right
  joins =
    ext: idx: r:
    b.foldl' (ss: a: b.concatMap (s: b.filter (x: x != null) (map (unify s a) (candidates idx s a))) ss)
      [
        { }
      ]
      (b.filter (a: !(ext ? ${b.head a})) (r.pos or [ ]));
  # the joins where every positive external is true and no negative one is
  bindings =
    ext: idx: r:
    b.filter (
      s:
      b.all (a: call ext s a == true) (b.filter (a: ext ? ${b.head a}) (r.pos or [ ]))
      && !b.any (a: call ext s a == true) (b.filter (a: ext ? ${b.head a}) (r.neg or [ ]))
    ) (joins ext idx r);
  # tuples by relation, and by the value at each position: a join reads only the tuples that can match a bound term
  byRel =
    tuples:
    b.mapAttrs (
      _: ts:
      {
        all = ts;
      }
      // b.listToAttrs (
        b.genList (i: {
          name = toString i;
          value = b.groupBy (t: k (b.elemAt t i)) (b.filter (t: b.length t > i) ts);
        }) (b.foldl' (m: t: if b.length t > m then b.length t else m) 0 ts)
      )
    ) (b.groupBy (x: b.head x) tuples);
  # the tuples an atom can match under s: the smallest bucket of a bound position, or all of its relation
  boundIn = s: t: !(isVar t) || s ? ${t.var};
  bucketIn =
    rel: s: a: i:
    rel.${toString i}.${k (b.elemAt (sub s [ (b.elemAt a i) ]) 0)} or [ ];
  smallest = all: b.foldl' (m: x: if b.length x < b.length m then x else m) all;
  candidatesIn =
    rel: s: a:
    smallest rel.all (
      map (bucketIn rel s a) (
        b.filter (i: boundIn s (b.elemAt a i)) (b.genList (i: i + 1) (b.length a - 1))
      )
    );
  candidates =
    idx: s: a:
    candidatesIn (idx.${b.head a} or { all = [ ]; }) s a;
  # what may hold: the least model of the rules without their negative atoms, over the facts (an upper bound of the WFM)
  possible =
    ext: rules: known:
    possibleNext ext rules known (
      b.attrValues (
        index (known ++ b.concatMap (r: map (s: sub s r.head) (bindings ext (byRel known) r)) rules)
      )
    );
  possibleNext =
    ext: rules: known: next:
    if b.length next == b.length known then known else possible ext rules next;
  # a literal (a relation called by reference, `yen.relations.serves h`) is its atom; an instance term is its
  # identity { kind; name; }, so two reads of one instance are one term. Any other atom stays as it is.
  term = t: if b.isAttrs t && t ? kind && t ? name then { inherit (t) kind name; } else t;
  atom = x: if b.isAttrs x && x ? atom then map term x.atom else x;
  # the rule as written, each atom normalized: an answer that names a rule shows the keys it was given
  rule =
    r:
    r
    // b.mapAttrs (n: v: if n == "head" then atom v else map atom v) (
      b.intersectAttrs {
        head = 0;
        pos = 0;
        neg = 0;
      } r
    );
  # ── the functions on keyed atoms; the public names below normalize literals once at the entry ──
  isExtIn = ext: a: ext ? ${b.head a};
  # the ground instances of the rules over idx (relation -> tuples), external atoms decided, then dropped
  groundIn = ext: rules: idx: {
    rules = b.concatMap (
      r:
      map (s: {
        head = sub s r.head;
        pos = map (sub s) (b.filter (a: !isExtIn ext a) (r.pos or [ ]));
        neg = map (sub s) (b.filter (a: !isExtIn ext a) (r.neg or [ ]));
      }) (bindings ext idx r)
    ) rules;
    faults = b.concatMap (
      r:
      b.concatMap (
        s:
        map (sub s) (
          b.filter (a: isExtIn ext a && !b.isBool (call ext s a)) ((r.pos or [ ]) ++ (r.neg or [ ]))
        )
      ) (joins ext idx r)
    ) rules;
  };
  groundWithRaw =
    ext: rules: facts:
    groundIn ext rules (byRel (possible ext rules (b.attrValues (index facts))));
in
{
  inherit
    isVar
    comparisons
    atom
    rule
    groundWithRaw
    ;
}
