# An eval part: map: fill the args yen answers; other args stay open (`__functionArgs`)
# A part is `_: st:`; `st` is the state of one eval: the names of every part, `root`, and the base helpers.
_: st:
let
  inherit (st)
    attrNames
    b
    elem
    errWith
    filter
    first
    functionArgs
    genAttrs
    head
    isFunction
    isRen
    kindArgs
    mapAttrs
    nearestArg
    orNull
    receiverIn
    sinkNames
    sourcesAt
    ;
  # ── map: fill the args yen answers; other args stay open (`__functionArgs`) ──
  # the scope an arg reads: the scope itself, the nearest instance of a kind, or a sink's receiver
  argScope =
    s: n:
    if n == "scope" || n == "sinks" then
      s
    else if elem n kindArgs then
      nearestArg n s
    else if elem n sinkNames then
      receiverIn n s.rup
    else
      null;
  argAt =
    s: n:
    if n == "sinks" then
      [ (sinksAt s) ]
    else if n == "scope" || elem n kindArgs then
      orNull (argScope s n)
    else
      (sourcesAt s [ ]).${n} or [ ];
  # the fixed arg `sinks`: each sink that has a receiver up the tree, read at the nearest one (as a named sink arg)
  sinksAt =
    s:
    mapAttrs (_: head) (
      b.removeAttrs (sourcesAt s [ ]) (
        filter (n: receiverIn n s.rup == null) sinkNames
        ++ [
          "scope"
          "tree"
        ]
      )
    );
  # nixpkgs lib.functionArgs rule: a functor with `__functionArgs` is a function. yen writes these (below) and reads them.
  isFn = f: isFunction f || f ? __functionArgs;
  fnArgs = f: f.__functionArgs or (functionArgs f);
  isAttrsFn = f: fnArgs f != { } || b.match ".*<attrspat.*" (b.toXML f) != null; # toXML only for `{ ... }:` vs `x:`
  fill = s: v: if !isFn v then { ok = v; } else fillArgs s v (fnArgs v);
  # asked: the answer to each arg yen fills; none: the args with no answer
  fillArgs =
    s: v: fa:
    fillAsked s v fa (genAttrs (filter isRen (attrNames fa)) (argAt s));
  fillAsked =
    s: v: fa: asked:
    fillNone s v fa asked (filter (n: asked.${n} == [ ]) (attrNames asked));
  fillNone =
    s: v: fa: asked: none:
    fillWith s v fa (first (n: !fa.${n}) none) (mapAttrs (_: head) (removeAttrs asked none)) (
      removeAttrs fa (attrNames asked)
    );
  # missing: the first arg with no answer and no default; got: the filled args; rest: the args that stay open
  fillWith =
    s: v: fa: missing: got: rest:
    if !isAttrsFn v then
      errWith s.id "bare function: wrap it as `{ ... }:`" {
        code = "bare-function";
        fix = "write `{ ... }:` so yen knows which args to fill";
      }
    else if fa ? tree then
      errWith s.id "arg `tree` is a cycle source" {
        code = "arg";
        want = "tree";
        fix = "ask the tree from a `cycle`: `cycle = { tree, ... }: { tree = [ … ]; <sink> = …; }`";
      }
    else if missing != null then
      errWith s.id "arg `${missing}` has no answer" {
        code = "arg";
        want = missing;
        fix = "give `${missing}` a default (`${missing} ? null`) or make the element active only where it has an answer";
      } # Cycle: no source, no emission
    else if rest == { } then
      { ok = v got; }
    else
      {
        ok = {
          __functor = _: m: v (m // got);
          __functionArgs = rest;
        };
      };

in
{
  inherit
    argScope
    argAt
    sinksAt
    isFn
    fnArgs
    isAttrsFn
    fill
    ;
}
