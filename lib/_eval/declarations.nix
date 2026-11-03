# An eval part: declarations: queries on the files, in file order. A leaf is the first answer; `at` is all answers
# A part is `_: st:`; `st` is the state of one eval: the names of every part, `root`, and the base helpers.
_: st:
let
  inherit (st)
    all
    attrNames
    attrsIn
    b
    checkOf
    concatMap
    concatStringsSep
    curried
    datalog
    defsOf
    elem
    errWith
    filter
    first
    foldl'
    genAttrs
    head
    isAttrs
    isLeaf
    isRef
    length
    lit
    loaded
    loadWith
    mapAttrs
    names
    ownedBy
    ownedKeys
    refKind
    refsYen
    renderId
    sinkNames
    toList
    typesAt
    words
    ;
  # ── declarations: queries on the files, in file order. A leaf is the first answer; `at` is all answers ──
  # one lazy index over every file (zipAttrsWith): a lookup walks its path, never all files
  zipDefs = vs: {
    vals = vs;
    kids = b.zipAttrsWith (_: zipDefs) (filter (v: isAttrs v && !isLeaf v) vs);
  };
  answersIn =
    index: path:
    (foldl' (
      node: n:
      node.kids.${n} or {
        vals = [ ];
        kids = { };
      }
    ) index path).vals;
  answers = answersIn (zipDefs (defsOf loaded));
  answersRefs = answersIn (zipDefs (defsOf (loadWith refsYen)));
  # an `at` predicate: answers from several files are a union. A stored query's param named `at` is a type (#81)
  atKey =
    path:
    path != [ ]
    && b.elemAt path (length path - 1) == "at"
    && !(length path == 4 && head path == "queries" && b.elemAt path 2 == "params");
  sinkKeyOf = path: length path == 3 && head path == "aspects" && elem (b.elemAt path 2) sinkNames; # several files may each give an element
  declIn =
    ans: path:
    let
      hs = ans path;
    in
    if atKey path then
      concatMap toList hs
    else if hs == [ ] then
      null
    else if isAttrs (head hs) && !isLeaf (head hs) then
      genAttrs (names (attrsIn hs)) (n: declIn ans (path ++ [ n ]))
    else
      head hs;
  declErrors =
    path:
    let
      hs = answers path;
    in
    if atKey path || length hs < 2 || sinkKeyOf path then
      [ ]
    else if all (x: isAttrs x && !isLeaf x) hs then
      concatMap (n: declErrors (path ++ [ n ])) (names (attrsIn hs))
    else if all (x: x == head hs) hs then
      [ ]
    else
      [
        (errWith "declarations" "two answers for ${concatStringsSep "." path}" {
          code = "two-answers";
          inherit path;
          got = length hs;
          fix = "keep one answer for ${concatStringsSep "." path}: data never overrides data";
        })
      ];
  top = declIn answers [ ];
  topRefs = declIn answersRefs [ ];
  # a kind id is its declaration path: the name for a top kind, a list for a nested one, never a joined string
  kindDecl =
    id: refs: d:
    (if isAttrs d then d else { }) # not an attrset: a `not-a-kind` error, read as an empty kind
    // {
      __kind = id;
      check = checkOf { __kind = id; };
    }
    # the aspects the kind owns, as refs: `yen.kinds.host.aspects.web`
    // ownedBy aspects (declPath id)
    // (
      # #80: a `sinks` or a sink that is no attrset reads as none here; kindKeyErrors gives its error record
      if isAttrs (d.sinks or null) && isAttrs (refs.sinks or null) then
        {
          sinks = mapAttrs (n: v: withAt d.sinks.${n} (v // { __sink = n; })) (
            b.listToAttrs (
              map (n: {
                name = n;
                value = refs.sinks.${n};
              }) (filter (n: isAttrs refs.sinks.${n} && isAttrs (d.sinks.${n} or null)) (attrNames refs.sinks))
            )
          );
        }
      else if d ? sinks then
        { sinks = { }; }
      else
        { }
    ) # a sink is a ref: it carries its name
    // (
      if d ? kinds then
        {
          kinds =
            if isAttrs d.kinds then
              mapAttrs (c: kindDecl (toList id ++ [ c ]) refs.kinds.${c}) d.kinds
            else
              { };
        }
      else
        { }
    ); # a nested kind lives only under its parent
  kinds = mapAttrs (k: kindDecl k topRefs.kinds.${k}) (top.kinds or { }); # a kind is a type: its instances pass
  # a kind is found by its id, through its parents; `declPath` is where it is declared under `yen`
  kindAt = id: foldl' (d: c: d.kinds.${c} or { }) { inherit kinds; } (toList id); # an undeclared kind reads as { }, as before
  declPath =
    id:
    concatMap (c: [
      "kinds"
      c
    ]) (toList id);
  leafOf = id: b.elemAt (toList id) (length (toList id) - 1);
  # the scope id of a data path of kind, name pairs; a trailing kind alone names its parent
  idAt =
    at:
    concatStringsSep "/" (
      b.genList (i: "${b.elemAt at (2 * i)}:${b.elemAt at (2 * i + 1)}") (length at / 2)
    );
  # a spawned child of kind k: its nested kind when k declares one by that name, else the top kind
  childId = k: c: if (kindAt k).kinds or { } ? ${c} then toList k ++ [ c ] else c;
  # what an aspect sees of a kind: a ref, with its nested kinds as refs under it
  kindRef =
    d:
    {
      inherit (d) __kind check;
    }
    // (if d ? sinks then { sinks = mapAttrs (n: _: { __sink = n; }) d.sinks; } else { })
    // (if d ? kinds then { kinds = mapAttrs (_: kindRef) d.kinds; } else { })
    // ownedBy refsYen.aspects (declPath d.__kind)
    // mapAttrs (
      f: _:
      throw "yen.kinds.${renderId d.__kind}.${f}: an aspect reads a kind only as a ref (a type, a request)"
    ) (removeAttrs d (words "__kind check sinks kinds aspects"));
  # values come from the refs load; `at` reads data: stage diffs where aspects are active and where sinks receive
  withAt = d: v: v // (if d ? at then { inherit (d) at; } else { });
  # an aspect a kind owns runs, by default, on the scopes of that kind, as a nested kind is spawned by default
  ownerKind =
    n:
    let
      p = ownedKeys.${n} or [ ];
      ids = b.genList (i: b.elemAt p (2 * i + 1)) ((length p - 2) / 2);
    in
    if p == [ ] || head p != "kinds" then
      null
    else if length ids == 1 then
      head ids
    else
      ids;
  atOf = n: d: if d ? at || ownerKind n == null then d else d // { at = [ (kindAt (ownerKind n)) ]; };
  aspects = mapAttrs (n: a: withAt (atOf n top.aspects.${n}) (a // { __aspect = n; })) (
    topRefs.aspects or { }
  );
  # a relation is called by reference: `yen.relations.rank e 3` is the atom [ "rank" e 3 ]; one of arity 0 is a literal
  #: yen.relations.<name> :: term… -> literal -- a declared relation called by reference, one term per arity; arity 0 is the literal itself
  relations = mapAttrs (
    n: r:
    r
    // (
      if (r.arity or 1) == 0 then
        lit [ n ]
      else
        { __functor = _: curried (if r ? type then 1 else r.arity) (ts: lit ([ n ] ++ ts)) [ ]; }
    )
  ) (top.relations or { });
  # rule literals by reference, never by name: `yen.facts.<kind>.<field> S T`, `kind`, `has`, `instance`, `parent`
  # and the comparisons. A ref field with a variable target joins its instance; `#` variables are the literal's own.
  # `<kind>.<field>.set S`: the field of S holds a value (a ref field: whether or not its instance has a scope)
  factLits = {
    #: yen.facts.kind :: kind -> scope -> literal -- the scope is of that kind (yen.kinds.<kind>)
    kind =
      k: s:
      lit [
        "kind"
        (k.__kind or k.kind)
        s
      ];
    #: yen.facts.has :: aspect -> scope -> literal -- the aspect is active at the scope (yen.aspects.<name>)
    has =
      a: s:
      lit [
        "has"
        (a.__aspect or a.aspect)
        s
      ];
    #: yen.facts.instance :: scope -> instance -> literal -- the scope holds that instance (yen.<kind>.<name>)
    instance =
      s: r:
      lit [
        "instance"
        s
        r.kind
        r.name
      ];
    #: yen.facts.scope :: scope -> literal -- the scope exists
    scope =
      s:
      lit [
        "scope"
        s
      ];
    #: yen.facts.edge :: sink -> scope -> scope -> literal -- an element of the sink goes from the first scope to the second (yen.kinds.<kind>.sinks.<sink>)
    edge =
      k: f: t:
      lit [
        "edge"
        (k.__sink or k.sink)
        f
        t
      ];
    #: yen.facts.parent :: scope -> scope -> literal -- the second scope is the parent of the first
    parent =
      s: p:
      lit [
        "parent"
        s
        p
      ];
  }
  #: yen.facts.lt, yen.facts.neq :: term -> term -> literal -- a comparison of two bound terms
  // mapAttrs (
    n: _: x: y:
    lit [
      n
      x
      y
    ]
  ) datalog.comparisons
  // mapAttrs (k: d: mapAttrs (f: _: fieldLit k f) (d.fields or { })) kinds;
  #: yen.facts.<kind>.<field> :: scope -> term -> literal -- the field of the scope holds the term; for a ref field, the term is a scope of the instance it refers to, or a ref constant
  #: yen.facts.<kind>.<field>.set :: scope -> literal -- the field of the scope holds a value
  fieldLit =
    k: f:
    let
      isRefField = first (t: refKind t != null) (typesAt k [ f ]) != null;
      ref = s: [
        "ref"
        f
        s
        { var = "#k"; }
        { var = "#n"; }
      ];
    in
    {
      __functor =
        _: s: t:
        if !isRefField then
          lit [
            "val"
            f
            s
            t
          ]
        else if isRef t then
          lit [
            "ref"
            f
            s
            t.kind
            t.name
          ]
        else
          {
            atom = ref s;
            join = [
              [
                "instance"
                t
                { var = "#k"; }
                { var = "#n"; }
              ]
            ];
          };
      set =
        s:
        lit (
          if isRefField then
            ref s
          else
            [
              "val"
              f
              s
              { var = "#v"; }
            ]
        );
    };
  kindNames = attrNames kinds;
  # every kind id, top and nested, by walking the tree
  kindIds = concatMap idsFrom kindNames;
  idsFrom =
    id: [ id ] ++ concatMap (c: idsFrom (toList id ++ [ c ])) (attrNames ((kindAt id).kinds or { }));
  aspectNames = attrNames aspects;

in
{
  inherit
    zipDefs
    answersIn
    answers
    answersRefs
    atKey
    sinkKeyOf
    declIn
    declErrors
    top
    topRefs
    kindDecl
    kinds
    kindAt
    declPath
    leafOf
    idAt
    childId
    kindRef
    withAt
    ownerKind
    atOf
    aspects
    relations
    factLits
    fieldLit
    kindNames
    kindIds
    idsFrom
    aspectNames
    ;
}
