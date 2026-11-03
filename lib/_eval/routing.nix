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
  given = concatMap (
    s:
    concatMap (
      n:
      let
        a = aspects.${n};
        o = outAt n s;
      in
      if !active.${n}.${s.id} then
        [ ]
      else
        concatMap (
          k:
          let
            hs = answersRefs [
              "aspects"
              n
              k
            ];
            one = length hs < 2 || all (x: isAttrs x && !isLeaf x) hs;
          in
          # data merges; functions from several files each apply
          b.genList (i: {
            origin = "aspect ${n}" + (if one then "" else "#${toString i}");
            aspect = n;
            key = k;
            from = s;
            value = if one then a.${k} else b.elemAt hs i;
          }) (if one then 1 else length hs)
        ) (attrNames (removeAttrs a aspectMeta))
        ++ concatMap (
          k:
          let
            vs = toList o.${k};
          in
          b.genList (i: {
            origin = "aspect ${n}";
            aspect = n;
            key = k;
            from = s;
            value = b.elemAt vs i;
            raw = i; # position: a cycle may emit many
          }) (length vs)
        ) (attrNames (removeAttrs o outMeta))
    ) aspectNames
  ) scopes;
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
