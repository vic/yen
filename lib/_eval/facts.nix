# An eval part: facts and invariants: the fleet as typed atoms `[ rel t… ]`; `yen.invariants.<name>` gives Datalog rules over
# A part is `_: st:`; `st` is the state of one eval: the names of every part, `root`, and the base helpers.
_: st:
let
  inherit (st)
    active
    all
    any
    aspectNames
    attrNames
    b
    byId
    checkOf
    childrenAt
    combinators
    concatMap
    datalog
    declaredIn
    edbArity
    elem
    errorsFleet
    errWith
    factLits
    filesOf
    filter
    floor
    foldl'
    genAttrs
    genericClosure
    get
    graph
    groupBy
    head
    holds
    intersectAttrs
    isAttrs
    isFunction
    isList
    isPath
    isRef
    isString
    keySet
    labels
    length
    lit
    mapAttrs
    near
    question
    relations
    schema
    scopeMeta
    scopes
    shown
    static
    tail
    toList
    tools
    unsorted
    words
    yen
    ;
  # ── facts and invariants: the fleet as typed atoms `[ rel t… ]`; `yen.invariants.<name>` gives Datalog rules over them.
  # A true `bad` atom is a violation; an undefined one (a cycle through `not`) is an incomplete answer, never a pass.
  # a field value: `[ "ref" FIELD ID KIND NAME ]` for a ref, `[ "val" FIELD ID VALUE ]` for a string, int or bool, one
  # per list element (a path by its string). A float, function or derivation has no fact, so it is an error: an absence never passes on it
  fieldAtoms = concatMap (
    s:
    concatMap (
      f:
      let
        one =
          x:
          if isRef x && isString x.kind then
            [
              {
                atom = [
                  "ref"
                  f
                  s.id
                  x.kind
                  x.name
                ];
              }
            ]
          else if isString x || b.isInt x || b.isBool x then
            [
              {
                atom = [
                  "val"
                  f
                  s.id
                  x
                ];
              }
            ]
          else if isPath x then
            [
              {
                atom = [
                  "val"
                  f
                  s.id
                  (toString x)
                ];
              }
            ] # a path is stated by its string
          else if b.isFloat x || isFunction x || isAttrs x && x.type or null == "derivation" then
            [
              {
                error = errWith s.id "field `${f}` holds a ${b.typeOf x}: no fact can state it" {
                  code = "unencodable";
                  path = [ f ];
                  got = b.typeOf x;
                  fix = "give the field a string, an int, a bool or a ref";
                };
              }
            ]
          else if isAttrs x then
            [
              {
                opaque = f;
                inherit (s) id;
              }
            ] # an attrset is data no fact states: a rule that must see it marks the verdict opaque (.41)
          else
            [ ];
      in
      if isList (shown s.kind f s.${f}) then
        concatMap one (shown s.kind f s.${f})
      else
        one (shown s.kind f s.${f})
    ) (attrNames (removeAttrs s scopeMeta))
  ) unsorted;
  #: result.facts :: [ atom ] -- the fleet as typed atoms that rules read
  facts =
    map (s: [
      "scope"
      s.id
    ]) scopes
    ++ map (s: [
      "instance"
      s.id
      s.kind
      s.name
    ]) scopes # a ref names KIND NAME: this finds its scopes
    ++ map (s: [
      "parent"
      s.id
      s.parent.id
    ]) (filter (s: s.parent != null) scopes)
    ++ map (s: [
      "kind"
      s.kind
      s.id
    ]) scopes
    ++ concatMap (
      n:
      map (s: [
        "has"
        n
        s.id
      ]) (filter (s: active.${n}.${s.id}) unsorted)
    ) aspectNames
    ++ map (e: [
      "edge"
      e.sink
      e.from
      e.to
    ]) graph.edges
    ++ map (e: [
      "error"
      (e.code or "error")
      e.from
    ]) errorsFleet
    ++ concatMap (x: if x ? atom then [ x.atom ] else [ ]) fieldAtoms;
  #: result.check :: { … } -- the invariants verdict, with its certificate, seal and explanations (below)
  check =
    let
      D = datalog;
      invs = yen.invariants;
      # a rule is a function of its variables, `{ H, D }: { bad = H; pos = [ … ]; neg = [ … ]; }`, its literals by
      # reference (yen.facts, yen.relations). One call with { var = "H"; } terms gives the rule as data (D3), so every
      # rule a verdict uses can be read and certified. `bad = t` is [ "bad" <invariant> t ]; `head = l` derives l
      ruleFns =
        n:
        if isFunction invs.${n} then
          [ invs.${n} ]
        else if isList invs.${n} then
          invs.${n}
        else
          [ ];
      rulesOf = n: map (readRule n) (filter isFunction (ruleFns n));
      readRule =
        n: f:
        let
          r = f (mapAttrs (x: _: { var = x; }) (b.functionArgs f));
          # a literal only by reference: a hand-written list is a bad atom
          literal = l: if isAttrs l && isList (l.atom or null) && isList (l.join or null) then l else null;
          ls = map literal (r.pos or [ ] ++ r.neg or [ ]);
          # the literal's own `#` variables, numbered by its place
          own =
            i: t: if D.isVar t && b.substring 0 1 t.var == "#" then { var = "${t.var}${toString i}"; } else t;
          at =
            i:
            if b.elemAt ls i == null then
              {
                atom = null;
                join = [ ];
              }
            else
              {
                atom = map (own i) (b.elemAt ls i).atom;
                join = map (map (own i)) (b.elemAt ls i).join;
              };
          pos = b.genList at (length (r.pos or [ ]));
          neg = b.genList (i: at (i + length pos)) (length (r.neg or [ ]));
        in
        {
          head =
            if r ? bad then
              [
                "bad"
                n
              ]
              ++ (if isList r.bad then r.bad else [ r.bad ])
            else
              (literal (r.head or null)).atom or null;
          # a negated ref joins its target's instance in pos: every scope has one instance fact, so this is exact
          pos = concatMap (l: [ l.atom ] ++ l.join) pos ++ concatMap (l: l.join) neg;
          neg = map (l: l.atom) neg;
        };
      shapeErrors = map (
        n:
        errWith "invariant ${n}" "an invariant is a rule function or a list of them, not data" {
          code = "invariant-data";
          path = [
            "invariants"
            n
          ];
          fix = "write each rule as { H, … }: { bad = H; pos = [ (yen.facts.host.addr H X) ]; neg = [ … ]; }";
        }
      ) (filter (n: !all isFunction (ruleFns n) || ruleFns n == [ ]) (attrNames invs));
      # externals decide atoms on bound terms: the comparisons, a relation with `holds = terms: bool`, and a
      # relation with `type` (rung 4: a type is a predicate, true when the term passes its check)
      externals =
        D.comparisons
        // mapAttrs (_: r: if r ? type then (ts: checkOf r.type (head ts)) else r.holds) (
          intersectAttrs (genAttrs (filter (n: yen.relations.${n} ? holds || yen.relations.${n} ? type) (
            attrNames yen.relations
          )) (_: null)) yen.relations
        );
      # every relation a rule may name: the extracted ones, the externals, and the user's; `bad` takes any arity
      arity =
        edbArity
        // mapAttrs (_: _: 2) D.comparisons
        // mapAttrs (_: r: if r ? type then 1 else r.arity) yen.relations;
      isAtom =
        a:
        isList a
        && a != [ ]
        && isString (head a)
        && all (t: isString t || b.isInt t || b.isBool t || D.isVar t) (tail a);
      isCmp = a: externals ? ${head a};
      varsOf = concatMap (a: map (t: t.var) (filter D.isVar (tail a)));
      # the first thing wrong with a rule, as { code; error; got; }, or null
      problem =
        r:
        let
          atoms = [ r.head ] ++ r.pos or [ ] ++ r.neg or [ ];
          bound = varsOf (filter (a: !isCmp a) (r.pos or [ ]));
          free = filter (x: !elem x bound) (
            varsOf ([ r.head ] ++ r.neg or [ ] ++ filter isCmp (r.pos or [ ]))
          );
          unknownRel = filter (a: !(arity ? ${head a}) && head a != "bad") atoms;
          wrongArity = filter (a: arity ? ${head a} && length (tail a) != arity.${head a}) atoms;
        in
        if !(isAttrs r && r ? head) || !all isAtom atoms then
          {
            code = "bad-atom";
            error = "a rule literal comes from yen.facts or yen.relations, and its terms are variables, strings, ints or bools";
            got = static.jsonSafe r;
          }
        else if edbArity ? ${head r.head} || isCmp r.head then
          {
            code = "edb-head";
            error = "a rule derives `${head r.head}`, a relation yen or a function decides: a rule never states it";
            got = r.head;
          }
        else if unknownRel != [ ] then
          {
            code = "unknown-relation";
            error = "no relation ${head (head unknownRel)}: declare it in yen.relations";
            got = head (head unknownRel);
            near = near (head (head unknownRel)) (attrNames arity);
          }
        else if wrongArity != [ ] then
          {
            code = "arity";
            error = "${head (head wrongArity)} takes ${toString arity.${head (head wrongArity)}} terms";
            got = head wrongArity;
          }
        else if free != [ ] then
          {
            code = "unsafe-rule";
            error = "variable ${head free} is not bound by a positive atom";
            got = free;
          }
        else
          null;
      checked = concatMap (
        n:
        map (r: {
          inherit n r;
          p = problem r;
        }) (rulesOf n)
      ) (attrNames invs);
      #: result.check.errors :: [ error ] -- the errors of the invariants themselves: shapes, relations, unsafe rules
      errors =
        shapeErrors
        ++ map (
          x:
          errWith "invariant ${x.n}" x.p.error (
            removeAttrs x.p [ "error" ]
            // {
              path = [
                "invariants"
                x.n
              ];
            }
          )
        ) (filter (x: x.p != null) checked)
        # a derived tuple of a user relation that fails the relation's check
        ++
          map
            (
              a:
              errWith "relation ${head a}" "${head a} derives ${b.toJSON (tail a)}, which fails its check" {
                code = "relation-check";
                got = a;
                path = [
                  "relations"
                  (head a)
                ];
              }
            )
            (
              filter (
                a: yen.relations.${head a}.check or null != null && !checkOf yen.relations.${head a} (tail a)
              ) m.true
            )
        # an external whose function gave no bool: the verdict cannot rest on it
        ++ map (
          a:
          errWith "relation ${head a}" "${head a} answers ${b.toJSON (tail a)} with no bool" {
            code = "external-not-bool";
            got = a;
            path = [
              "relations"
              (head a)
            ];
          }
        ) grounded.faults;
      grounded = D.groundWith externals (map (x: x.r) (filter (x: x.p == null) checked)) facts;
      ground = grounded.rules;
      key = b.toJSON;
      mentioned = keySet (map key (concatMap (r: r.pos ++ r.neg) ground));
      verdictProgram = ground ++ D.facts (filter (a: mentioned ? ${key a}) facts);
      m = D.wfs verdictProgram;
      # the staged certificate of the verdict (rung 3), and the plain checker's answer on it: valid, and it states
      # the same violations, with every undefined `bad` atom left out (incomplete)
      #: result.check.certificate :: { true; false; } -- each decided atom with its stage; each true atom with the rule that proves it
      certificate = D.certify verdictProgram;
      certAtoms = es: b.sort b.lessThan (map (x: key x.atom) es);
      #: result.check.certified :: bool -- the small checker accepts the certificate and it states the same verdict
      certified =
        (D.checkCertificate verdictProgram certificate).valid
        && certAtoms (filter (x: isBad x.atom) certificate.true) == b.sort b.lessThan (map key violations)
        && !any (a: elem (key a) (certAtoms (certificate.true ++ certificate.false))) incomplete;
      # each term as its key, the identity at the JSON edge; a variable stays { var; }
      keyTerm = t: if D.isVar t then { inherit (t) var; } else key t;
      keyRule = r: {
        head = map keyTerm r.head;
        pos = map (map keyTerm) (r.pos or [ ]);
        neg = map (map keyTerm) (r.neg or [ ]);
      };
      #: result.check.lean :: { rules; facts; externals; certificate = { proved; refuted; }; } -- the verdict as the Lean checker reads it (lean/Main.lean): the rules as written, the facts, and the certificate; JSON-safe
      lean = {
        rules = map keyRule valid;
        facts = map (map key) facts;
        externals = attrNames externals;
        certificate = {
          proved = map (e: {
            atom = map key e.atom;
            inherit (e) stage;
            rule = keyRule e.rule;
          }) certificate.true;
          refuted = map (e: {
            atom = map key e.atom;
            inherit (e) stage;
          }) certificate.false;
        };
      };
      isBad = a: head a == "bad";
      #: result.check.violations :: [ atom ] -- the true bad atoms
      violations = filter isBad m.true;
      #: result.check.incomplete :: [ atom ] -- the undefined bad atoms: an incomplete answer, never a pass
      incomplete = filter isBad m.undefined;
      # .41 (E1): a relation reached from `bad` through an even number of `not` must be complete. Yen's facts are,
      # but for a field value no fact states (an attrset): such a field read there makes the verdict opaque, not ok.
      # A node is a relation; a `val` atom with a constant field is its own node, `val/*` when the field is a variable
      node =
        a:
        if head a == "val" then "val/${if isString (b.elemAt a 1) then b.elemAt a 1 else "*"}" else head a;
      valid = map (x: x.r) (filter (x: x.p == null) checked);
      reached = keySet (
        map (x: x.key) (genericClosure {
          startSet = [
            {
              key = "bad@0";
              n = "bad";
              odd = false;
            }
          ];
          operator =
            x:
            concatMap (
              r:
              let
                next = flip: a: {
                  key = "${node a}@${if x.odd != flip then "1" else "0"}";
                  n = node a;
                  odd = x.odd != flip;
                };
              in
              map (next false) (r.pos or [ ]) ++ map (next true) (r.neg or [ ])
            ) (filter (r: node r.head == x.n) valid);
        })
      );
      opaqueAt = groupBy (x: x.opaque) (filter (x: x ? opaque) fieldAtoms);
      #: result.check.opaque :: [ { field; scopes; } ] -- fields a rule reads where no fact can state the value (an attrset): the verdict is not ok
      opaque = map (f: {
        field = f;
        scopes = map (x: x.id) opaqueAt.${f};
      }) (filter (f: reached ? "val/${f}@0" || reached ? "val/*@0") (attrNames opaqueAt));
      # .42: the seal binds a verdict to the engine, the rules and the facts it was computed from. Anything else that
      # changes a verdict changes one of them. Checking a seal is evaluating again: `verify` answers { ok; why; }
      hash = x: b.hashString "sha256" (b.toJSON x);
      binding = {
        # every file of the engine: its entry, its prelude, the Datalog it proves with, and each part of an eval
        engine = hash (
          map (f: b.hashFile "sha256" f) (
            [
              ../_engine.nix
              ../_prelude.nix
              ../datalog.nix
            ]
            ++ map (n: ./. + "/${n}") (attrNames (b.readDir ./.))
          )
        );
        rules = hash (map (x: x.r) checked);
        facts = hash facts;
      };
      refuse = why: {
        ok = false;
        inherit why;
      };
      #: result.check.verify :: seal -> { ok; why ? ; } -- evaluate again and compare: engine, rules, facts and certificate
      verify =
        s:
        if s.binding.engine != binding.engine then
          refuse "engine"
        else if s.binding.rules != binding.rules then
          refuse "rules"
        else if s.binding.facts != binding.facts then
          refuse "facts"
        else if !(D.checkCertificate verdictProgram s.certificate).valid then
          refuse "certificate"
        else if s.violations != violations || s.incomplete != incomplete then
          refuse "verdict"
        else
          { ok = true; };
      # .43: where a fact comes from, beside the fact, never in it: an edge's origin, or the files that declare its
      # instance, its field, or its aspect
      #: result.check.from :: literal -> [ origin ] -- where a fact comes from: the edge origin, or the files that declare its instance, field or aspect
      from = question (
        a:
        let
          r = head a;
          # the scope id: [ "kind" K ID ], [ "val" F ID V ] and [ "ref" F ID K N ] hold it second; the others first
          s = byId.${b.elemAt a (if elem r (words "kind val ref") then 2 else 1)} or null;
          inst =
            path:
            if s == null then
              [ ]
            else
              declaredIn (
                [
                  s.kind
                  s.name
                ]
                ++ path
              );
        in
        if r == "edge" then
          map (e: e.origin) (
            filter (
              e:
              [
                "edge"
                e.sink
                e.from
                e.to
              ] == a
            ) graph.edges
          )
        else if r == "has" then
          filesOf (b.elemAt a 1)
        else if r == "val" || r == "ref" then
          inst [ (b.elemAt a 1) ]
        else if r == "error" then
          [ (b.elemAt a 2) ]
        else
          inst [ ]
      );
      program = ground ++ D.facts facts;
      # the verdict's model plus the facts no rule body reads: they change no other atom, so it is the model of `program`
      model = m // {
        true = m.true ++ filter (a: !(mentioned ? ${key a})) facts;
      };
    in
    {
      inherit
        violations
        incomplete
        errors
        certificate
        certified
        lean
        verify
        from
        opaque
        ;
      #: result.check.seal :: { binding; certificate; violations; incomplete; } -- the verdict bound to the hashes of the engine, the rules and the facts
      seal = static.jsonSafe {
        inherit
          binding
          certificate
          violations
          incomplete
          ;
      };
      #: result.check.ok :: bool -- no violation, no incomplete atom, no opaque field
      ok = violations == [ ] && incomplete == [ ] && opaque == [ ];
      # the literals of yen.facts and yen.relations, for a question from outside the fleet: a ref or its identity
      #: result.check.facts, result.check.relations :: … -> literal -- yen.facts and yen.relations; a kind, aspect or sink may be its identity { kind; }, { aspect; }, { sink; }
      facts = factLits;
      inherit relations;
      #: result.check.bad :: { invariant = term or [ term ] -> literal; } -- the violation of an invariant, by reference: a scope, or an instance with one scope
      bad = mapAttrs (
        n: _: t:
        lit (
          [
            "bad"
            n
          ]
          ++ (if isList t then t else [ t ])
        )
      ) invs;
      #: result.check.why :: literal -> [ rule ] -- the rules that make the literal true
      why = question (D.why program model);
      #: result.check.whyNot :: literal -> [ { rule; missing; blocking; undefinedBody; } ] -- why the literal is not true
      whyNot = question (D.whyNot program model);
      #: result.check.proof :: literal -> tree -- the proof tree of a true literal
      proof = question (D.proof program model);
      #: result.check.invariants :: [ name ] -- the names of the invariants
      invariants = attrNames invs;
    };
  #: yen.lib.same :: x -> y -> bool -- x and y are the same instance; a non-instance is never the same
  same = x: y: isRef x && isRef y && x.kind == y.kind && x.name == y.name; # total: a non-instance is never the same
  #: yen.lib.pointing :: name -> { name = instance; } -> scope -> { name = instance; } -- the instances whose field points at the scope: one ref, or a list that holds it (a `spawns` by a ref field)
  pointing =
    f: xs: s:
    b.removeAttrs xs (filter (n: !any (same s) (toList (xs.${n}.${f} or [ ]))) (attrNames xs));
  lib =
    tools
    #: yen.lib.all :: [ predicate ] -> predicate -- every predicate holds
    #: yen.lib.not :: predicate -> predicate -- the predicate does not hold
    #: yen.lib.within :: predicate -> predicate -- the predicate holds at a scope above
    #: yen.lib.below :: predicate -> predicate -- the predicate holds at a child scope
    // genAttrs combinators (
      c: p: {
        "__${c}" = p;
        __functor = self: holds self;
      }
    )
    // {
      inherit
        holds
        graph
        declaredIn
        labels
        floor
        schema
        ; # queries readable inside the fleet (docs); `check` and `context` read errors, so not here
      inherit same pointing;
      #: yen.lib.scopesOf :: instance -> [ scope ] -- the scopes of an instance
      scopesOf = x: filter (s: s.kind == x.kind && s.name == x.name) scopes;
      #: yen.lib.children :: predicate -> scope -> [ scope ] -- the children of the scope where the predicate holds, sorted
      children = p: s: filter (holds p) (childrenAt.${s.id} or [ ]); # the children of a scope where p holds, sorted
      #: yen.lib.cascade :: [ name ] -> [ scope ] -> value or null -- the first answer for path along a list of scopes
      cascade = path: foldl' (a: x: if a != null then a else (get path x).ok or null) null; # first answer along a list of scopes
    };
in
{
  inherit
    fieldAtoms
    facts
    check
    same
    pointing
    lib
    ;
}
