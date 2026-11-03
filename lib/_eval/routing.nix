# An eval part: routing: nearest ancestor-or-self receiver (Cycle isolateSink tags the identity)
# A part is `_: st:`; `st` is the state of one eval: the names of every part, `root`, and the base helpers.
_: st:
let
  inherit (st)
    active
    all
    answersRefs
    aspectMeta
    aspectNames
    aspects
    attrNames
    b
    concatMap
    filter
    first
    genericClosure
    groupBy
    holds
    isAttrs
    isLeaf
    kindAt
    kindIds
    length
    orNull
    outAt
    outMeta
    scopes
    sinkMeta
    toList
    uniq
    ;
  # ── routing: nearest ancestor-or-self receiver (Cycle isolateSink tags the identity) ──
  sinkOf = s: k: ((kindAt s.kind).sinks or { }).${k} or null;
  sinkKeys = d: attrNames (removeAttrs d sinkMeta);
  sinkNames = uniq (concatMap (id: attrNames ((kindAt id).sinks or { })) kindIds);
  above = s: if s.parent == null then [ ] else s.parent.rup;
  receiverIn = k: first (r: sinkOf r k != null && holds ((sinkOf r k).at or (_: true)) r);
  given = concatMap (s: concatMap (givenBy s) aspectNames) scopes;
  givenBy =
    s: n:
    if !active.${n}.${s.id} then
      [ ]
    else
      concatMap (aspectGives s n) (attrNames (removeAttrs aspects.${n} aspectMeta))
      ++ concatMap (cycleGives s n (outAt n s)) (attrNames (removeAttrs (outAt n s) outMeta));
  # hs: the values of key k in each file of aspect n
  aspectGives =
    s: n: k:
    givenFrom s n k (answersRefs [
      "aspects"
      n
      k
    ]);
  givenFrom =
    s: n: k: hs:
    givenAs s n k hs (length hs < 2 || all (x: isAttrs x && !isLeaf x) hs);
  # data merges (one): functions from several files each apply
  givenAs =
    s: n: k: hs: one:
    b.genList (i: {
      origin = "aspect ${n}" + (if one then "" else "#${toString i}");
      aspect = n;
      key = k;
      from = s;
      value = if one then aspects.${n}.${k} else b.elemAt hs i;
    }) (if one then 1 else length hs);
  cycleGives =
    s: n: o: k:
    cycleElems s n k (toList o.${k});
  cycleElems =
    s: n: k: vs:
    b.genList (i: {
      origin = "aspect ${n}";
      aspect = n;
      key = k;
      from = s;
      value = b.elemAt vs i;
      raw = i; # position: a cycle may emit many
    }) (length vs);
  direct = concatMap (e: map (to: e // { inherit to; }) (orNull (receiverIn e.key e.from.rup))) (
    filter (e: e.key != "errors") given
  ); # no receiver above: dropped. A static key no kind declares as a sink is an error in keyErrors; keys a cycle function returns are not checked
  fire = sink: r: {
    key = "${sink}@${r.id}";
    inherit sink r;
  };
  # what a fired sink gives on: each of its keys to that key's receiver (above it, for its own key)
  feeds =
    f:
    concatMap (
      k: map (to: { inherit k to; }) (orNull (receiverIn k (if k == f.sink then above f.r else f.r.rup)))
    ) (sinkKeys (sinkOf f.r f.sink));
  fired = genericClosure {
    # which (sink, receiver) pairs fire: existence only
    startSet = map (e: fire e.key e.to) direct;
    operator = f: map (x: fire x.k x.to) (feeds f);
  };
  fromSinks = concatMap (
    f:
    map (x: {
      origin = "sink ${f.sink}";
      key = x.k;
      from = f.r;
      inherit (x) to;
      value = (sinkOf f.r f.sink).${x.k};
    }) (feeds f)
  ) fired;
  routed = direct ++ fromSinks;
  byTo = groupBy (e: "${e.key}@${e.to.id}") routed;

in
{
  inherit
    sinkOf
    sinkKeys
    sinkNames
    above
    receiverIn
    given
    direct
    fire
    feeds
    fired
    fromSinks
    routed
    byTo
    ;
}
