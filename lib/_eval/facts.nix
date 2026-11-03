# An eval part: facts and invariants: the fleet as typed atoms `[ rel t… ]`; `yen.invariants.<name>` gives Datalog rules over
# A part is `_: st:`; `st` is the state of one eval: the names of every part, `root`, and the base helpers.
_: st:
let
  inherit (st)
    active
    any
    aspectNames
    attrNames
    b
    childrenAt
    combinators
    concatMap
    declaredIn
    errorsFleet
    errWith
    filter
    floor
    foldl'
    genAttrs
    get
    graph
    holds
    isAttrs
    isFunction
    isList
    isPath
    isRef
    isString
    labels
    schema
    scopeMeta
    scopes
    shown
    toList
    tools
    unsorted
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
      if isList (shown s.kind f s.${f}) then
        concatMap (fieldAtom s f) (shown s.kind f s.${f})
      else
        fieldAtom s f (shown s.kind f s.${f})
    ) (attrNames (removeAttrs s scopeMeta))
  ) unsorted;
  # one value x of field f of scope s: a fact, an error, or opaque
  fieldAtom =
    s: f: x:
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
    same
    pointing
    lib
    ;
}
