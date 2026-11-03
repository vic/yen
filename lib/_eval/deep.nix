# An eval part: the deep check: the parts a type owes at a frontier, checked after evaluation, so a value is forced only when
# A part is `_: st:`; `st` is the state of one eval: the names of every part, `root`, and the base helpers.
_: st:
let
  inherit (st)
    attrNames
    concatMap
    concatStringsSep
    discharge
    errWith
    filter
    foldl'
    instances
    isAttrs
    isType
    kindAt
    memo
    moduleSinks
    parseOf
    receivers
    reduceModules
    renderId
    routed
    scopes
    sinkNames
    used
    ;
  # ── the deep check: the parts a type owes at a frontier, checked after evaluation, so a value is forced only when
  # verified, never while the fleet evaluates (lazy contracts: a check forces only what it is asked to) ──
  fieldLeaves =
    pre: fs:
    concatMap (
      f:
      if isType fs.${f} then
        [
          {
            path = pre ++ [ f ];
            type = fs.${f};
          }
        ]
      else if isAttrs fs.${f} then
        fieldLeaves (pre ++ [ f ]) fs.${f}
      else
        [ ]
    ) (attrNames fs);
  valueAt = path: v: foldl' (a: s: if isAttrs a then a.${s} or null else null) v path;
  oweOf =
    k: n: l:
    map
      (
        o:
        o
        // {
          path = l.path ++ o.path;
          from = "${renderId k}:${n}";
        }
      )
      (
        if valueAt l.path instances.${k}.${n} == null then
          [ ]
        else
          (parseOf l.type (valueAt l.path instances.${k}.${n})).owe or [ ]
      );
  fieldOwe = concatMap (
    k:
    concatMap (n: concatMap (oweOf k n) (fieldLeaves [ ] ((kindAt k).fields or { }))) (
      attrNames instances.${k}
    )
  ) (attrNames instances);
  sinkOwe =
    concatMap (k: concatMap (r: memo.${k}.${r.id}.owe) (receivers k)) sinkNames
    ++ concatMap (c: (reduceModules c).owe) (
      filter (c: c != "yen" && used ? ${c}) (attrNames moduleSinks)
    );
  deep = map (
    o:
    errWith o.from "${concatStringsSep "." (map toString o.path)}: a part is not ${o.want}" {
      code = "deep";
      path = map toString o.path;
      inherit (o) want;
    }
  ) (discharge (fieldOwe ++ sinkOwe));
  #: result.graph, yen.lib.graph :: { scopes; edges; } -- the scope tree and the routed elements: who gives what to whom
  graph = {
    scopes = map (s: { inherit (s) id kind name; }) scopes;
    edges = map (e: {
      sink = e.key;
      from = e.from.id;
      to = e.to.id;
      inherit (e) origin;
    }) routed;
  }; # origin: "aspect x" or "sink y": who gave it
in
{
  inherit
    fieldLeaves
    valueAt
    oweOf
    fieldOwe
    sinkOwe
    deep
    graph
    ;
}
