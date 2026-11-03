# Type queries of the engine: what a type is, checks, refs, secrets, and reads along a path.
self:
let
  inherit (builtins)
    attrNames
    concatMap
    elemAt
    foldl'
    genList
    isAttrs
    isBool
    isFunction
    isList
    length
    mapAttrs
    typeOf
    ;
  inherit (self._core.helpers) isRef renderId;
  typeName =
    t:
    t.name or t.description
      or (if t ? __kind then "a ${renderId t.__kind} ref" else "a value its check accepts");
  # a type is tagged `__type`, or has `check` (untagged types still work), or is a kind
  isLeaf =
    v:
    !isAttrs v
    || v ? __type
    || v ? check
    || v ? __kind
    || v ? __functor
    || (v.type or null) == "derivation";
  isType = t: isAttrs t && (t ? __type || t ? check || t ? __kind);
  # the kind a type refers to, through `maybe` and `listOf`; null when it is no ref
  refKind =
    t:
    if t ? __kind then
      t.__kind
    else if t ? __maybe then
      refKind t.__maybe
    else if t ? __of then
      refKind t.__of
    else
      null;
  # a secret value is stated by its hash; a type is secret itself or through `maybe`
  hide =
    v:
    "sha256:"
    + builtins.hashString "sha256" (
      builtins.toJSON (
        if isRef v then
          "${v.kind}:${v.name}"
        else if isFunction v then
          "<function>"
        else
          v
      )
    );
  isSecret = t: isAttrs t && (t ? __secret || t ? __maybe && isSecret t.__maybe);
  # parse gives { right = value; } or { left = { path; got; want; }; }; a type without `parse` parses by its check.
  # A check that gives no bool (a curried gen-types check) fails, never throws; `boolCheck` names it in the error
  outerOf =
    t:
    if t ? parse then
      t.parse
    else
      v:
      let
        c = if t ? __kind then isAttrs v && (v.kind or null) == t.__kind else t.check v;
      in
      if isBool c && c then
        { right = v; }
      else
        {
          left = {
            path = [ ];
            got = typeOf v;
            want = typeName t;
          };
        };
  # the frontier parse: the outer shape, then the elements of a `listOf` (`__of`) or `attrsOf` (`__values`). An element that
  # fails makes the whole value `left`, at the element's path; a nested `listOf` flattens. Combinators only describe.
  parseOf =
    t: v:
    let
      r = outerOf t v;
      firstLeft =
        rs: ns:
        foldl' (
          a: n:
          if a != null then
            a
          else if rs.${n} ? left then
            n
          else
            null
        ) null ns;
      lefted = n: e: {
        left = e.left // {
          path = [ n ] ++ e.left.path;
        };
      };
    in
    if r ? left then
      r
    else if t ? __of && isList v then
      let
        rs = map (parseOf t.__of) v;
        ix = genList (i: i) (length v);
        bad = foldl' (
          a: i:
          if a != null then
            a
          else if (elemAt rs i) ? left then
            i
          else
            null
        ) null ix;
      in
      if bad != null then
        lefted bad (elemAt rs bad)
      else if t.__of ? __of then
        { right = concatMap (e: e.right) rs; }
      else
        { right = map (e: e.right) rs; }
    else if t ? __values && isAttrs v then
      let
        rs = mapAttrs (_: parseOf t.__values) v;
        bad = firstLeft rs (attrNames v);
      in
      if bad != null then lefted bad rs.${bad} else { right = mapAttrs (_: e: e.right) rs; }
    else
      r;
  checkOf = t: v: parseOf t v ? right;
  boolCheck = t: v: t ? __kind || !(t ? check) || isBool (t.check v);
  get =
    path: v:
    foldl' (
      r: n: if r ? ok && isAttrs r.ok && !isLeaf r.ok && r.ok ? ${n} then { ok = r.ok.${n}; } else { }
    ) { ok = v; } path;
  attrsIn = xs: concatMap (x: if isAttrs x && !isLeaf x then attrNames x else [ ]) xs;
in
{
  inherit
    typeName
    isLeaf
    isType
    refKind
    hide
    isSecret
    parseOf
    checkOf
    boolCheck
    get
    attrsIn
    ;
}
