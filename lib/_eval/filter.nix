# An eval part: filter: every predicate is a function; refs, lists and the combinators are data the engine reads
# A part is `_: st:`; `st` is the state of one eval: the names of every part, `root`, and the base helpers.
_: st:
let
  inherit (st)
    above
    any
    aspectNames
    aspects
    b
    below
    combinators
    concatMap
    elem
    errWith
    filter
    first
    genericClosure
    head
    isAttrs
    isFunction
    isList
    isRef
    keySet
    length
    listToAttrs
    mapAttrs
    toList
    unsorted
    ;
  # ── filter: every predicate is a function; refs, lists and the combinators are data the engine reads ──
  # Three values: true, false, null (undefined). An aspect ref is memoised per scope (`__here`), so nested refs cost
  # once. An aspect on a cycle of refs is evaluated with a stack: back on the stack through a `not`, the answer is
  # undefined (Gelder, Ross, Schlipf: well-founded semantics, a = not b, b = not a); with no `not`, false (unfounded).
  refsOf =
    p:
    if isList p then
      concatMap refsOf p
    else if !isAttrs p then
      [ ]
    else if p ? __aspect then
      [ p.__aspect ]
    else
      concatMap (k: refsOf p."__${k}") (filter (k: p ? "__${k}") combinators);
  refs = mapAttrs (_: a: map (r: { key = r; }) (refsOf (a.at or [ ]))) aspects; # once per aspect
  reach = mapAttrs (
    n: _:
    map (x: x.key) (genericClosure {
      startSet = refs.${n};
      operator = x: refs.${x.key};
    })
  ) aspects;
  cyclic = mapAttrs (n: rs: elem n rs) reach;
  tainted = mapAttrs (n: rs: cyclic.${n} || any (r: cyclic.${r}) rs) reach; # can be undefined: it reaches a cycle
  or3 =
    vs:
    if elem true vs then
      true
    else if elem null vs then
      null
    else
      false;
  and3 =
    vs:
    if elem false vs then
      false
    else if elem null vs then
      null
    else
      true;
  eval3 =
    stack: p: s:
    if isFunction p then
      p s
    else if isList p then
      (if length p == 1 then eval3 stack (head p) s else or3 (map (q: eval3 stack q s) p)) # `at` is always a list (a union over files): one entry is the common case
    else if p ? __all then
      and3 (map (q: eval3 stack q s) p.__all)
    else if p ? __not then
      (
        let
          v = eval3 (map (x: x // { neg = true; }) stack) p.__not s;
        in
        if v == null then null else !v
      )
    else if p ? __within then
      or3 (map (eval3 stack p.__within) (above s))
    else if p ? __below then
      or3 (map (eval3 stack p.__below) (below s))
    else if p ? __functor then
      p s
    else if p ? __kind then
      s.kind == p.__kind
    else if p ? __aspect then
      let
        q = p.__aspect;
        f = frame q s;
        hit = first (x: x.key == f.key) stack;
      in
      if hit != null then
        (if hit.neg then null else false)
      else if stack == [ ] || !cyclic.${q} then
        s.__here.${q} # per scope: structure may depend on presence (Den #525) without the whole tree
      else
        eval3 (stack ++ [ f ]) (aspects.${q}.at or [ ]) s
    else
      isRef p && s.kind == p.kind && s.name == p.name;
  frame = q: s: {
    key = "${q}@${s.id}";
    neg = false;
  };
  here = s: mapAttrs (q: a: eval3 [ (frame q s) ] (a.at or [ ]) s) aspects;
  #: yen.lib.holds :: predicate -> scope -> bool -- the predicate holds at the scope (a kind, an instance, an aspect, a function, a list: any of them, or a combinator)
  holds =
    p: s:
    if isFunction p then
      p s
    else if p == [ ] then
      false
    else if isList p && length p == 1 && isFunction (head p) then
      (head p) s
    else
      eval3 [ ] p s == true; # fast paths: most predicates are functions, most sinks have no `at`
  # an aspect in the ref graph (it reads refs, or something reads it) goes through the memo; the others run directly
  inRefs = keySet (concatMap (n: if reach.${n} == [ ] then [ ] else [ n ] ++ reach.${n}) aspectNames);
  byScope =
    f: ss:
    listToAttrs (
      map (s: {
        name = s.id;
        value = f s;
      }) ss
    );
  #: result.active :: { aspect = { scope id = bool; }; } -- where each aspect is active
  active = mapAttrs (
    n: a: byScope (if inRefs ? ${n} then (s: s.__here.${n} == true) else holds (a.at or [ ])) unsorted
  ) aspects;
  #: result.undefined :: [ { aspect; scope; } ] -- the aspects whose at is neither true nor false at a scope (a cycle through not)
  undefined = concatMap (
    s:
    map (n: {
      aspect = n;
      scope = s.id;
    }) (filter (n: tainted.${n} && s.__here.${n} == null) aspectNames)
  ) unsorted;
  isPredicate =
    p:
    isFunction p || isList p || isAttrs p && (p ? __functor || p ? __kind || p ? __aspect || isRef p);
  # a typo must not read as false
  atErrors = concatMap (
    n:
    map (
      p:
      errWith "aspect ${n}" "`at` holds a ${b.typeOf p}, not a predicate" {
        code = "at";
        path = [
          "aspects"
          n
          "at"
        ];
        got = b.typeOf p;
        want = "a predicate: a function, a kind, instance or aspect ref, or a list";
      }
    ) (filter (p: !isPredicate p) (toList (aspects.${n}.at or [ ])))
  ) aspectNames;

in
{
  inherit
    refsOf
    refs
    reach
    cyclic
    tainted
    or3
    and3
    eval3
    frame
    here
    holds
    inRefs
    byScope
    active
    undefined
    isPredicate
    atErrors
    ;
}
