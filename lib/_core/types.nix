# Type queries of the engine: what a type is, checks, refs, secrets, and reads along a path.
self:
let
  inherit (builtins)
    attrNames
    concatMap
    foldl'
    isAttrs
    isBool
    isFunction
    ;
  inherit (self._core.helpers) isRef;
  typeName =
    t:
    t.name or t.description
      or (if t ? __kind then "a ${t.__kind} ref" else "a value its check accepts");
  isLeaf =
    v: !isAttrs v || v ? check || v ? __kind || v ? __functor || (v.type or null) == "derivation";
  isType = t: isAttrs t && (t ? check || t ? __kind);
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
  # a check that gives no bool (a curried gen-types check) fails, never throws; `boolCheck` names it in the error
  checkOf =
    t:
    if t ? __kind then
      (v: isAttrs v && (v.kind or null) == t.__kind)
    else
      (v: isBool (t.check v) && t.check v);
  boolCheck = t: v: t ? __kind || isBool (t.check v);
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
    checkOf
    boolCheck
    get
    attrsIn
    ;
}
