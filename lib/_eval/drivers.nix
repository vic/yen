# An eval part: the drivers
# A part is `_: st:`; `st` is the state of one eval: the names of every part, `root`, and the base helpers.
_: st:
let
  inherit (st)
    argScope
    attrNames
    byScope
    byTo
    concatMap
    concatStringsSep
    err
    errWith
    fill
    filter
    fnArgs
    genAttrs
    given
    instances
    isAttrs
    isFn
    isRef
    isType
    mapAttrs
    parseOf
    reduce
    scopes
    sinkNames
    sinkOf
    toList
    uniqueBy
    ;
  # ── the drivers ──
  idOf =
    e:
    if !isFn e.value then
      (if e ? raw then "${e.origin}|raw${toString e.raw}|${e.from.id}" else e.origin) # static content: once per receiver (Ren r13 rule 9)
    else
      "${e.origin}|"
      + concatStringsSep "," (map (n: (argScope e.from n).id or "") (attrNames (fnArgs e.value)));
  reduceAt =
    k: r:
    let
      d = sinkOf r k;
      es = uniqueBy (e: "${idOf e}@${r.id}") (byTo."${k}@${r.id}" or [ ]);
      filled = map (e: fill e.from e.value // { inherit e; }) es;
      okOf = x: x ? ok && (!(d ? of) || parseOf d.of x.ok ? right);
      # a sink `of` a kind gets refs; it reduces their instances (an element holds a ref, never instance data)
      resolve =
        v: if d ? of && isType d.of && d.of ? __kind && isRef v then instances.${v.kind}.${v.name} else v;
      red = (d.reduce or reduce.list) (
        map (x: {
          from = x.e.from;
          value = resolve x.ok;
        }) (filter okOf filled)
      );
      bad = map (
        x:
        if x ? error then
          removeAttrs x [ "e" ] // { error = "${x.e.origin}: ${x.error}"; } # the fill record keeps its code
        else
          errWith r.id "sink ${k}: element of ${x.e.origin} from ${x.e.from.id} fails `of`" { code = "of"; }
      ) (filter (x: !okOf x) filled);
    in
    {
      value = red.value;
      # the parts `of` did not force, for `result.deep`
      owe =
        if d ? of then
          concatMap (
            x:
            map (
              o:
              o
              // {
                path = [ k ] ++ o.path;
                from = r.id;
              }
            ) ((parseOf d.of x.ok).owe or [ ])
          ) (filter okOf filled)
        else
          [ ];
      errors =
        bad
        ++ map (
          e:
          e
          // {
            from = r.id;
            sink = k;
          }
        ) red.errors;
    }; # a strategy cannot know its receiver: the engine names it
  # a record or a message; `from` is always the giver
  emitted = concatMap (
    e:
    let
      x = fill e.from e.value;
    in
    if x ? ok then
      map (
        m:
        if isAttrs m then
          errWith e.from.id (m.error or "error") (removeAttrs m [ "from" ])
        else
          err e.from.id m
      ) (toList x.ok)
    else
      [ (x // { error = "${e.origin}: ${x.error}"; }) ]
  ) (filter (e: e.key == "errors") given);

  # ── run: sinks feed drivers, drivers feed sources, Nix laziness closes the loop. Every output is a query ──
  receivers = k: filter (s: byTo ? "${k}@${s.id}") scopes;
  # one reduction per (sink, receiver), shared by the `reduced` query, the errors and every arg that reads the sink
  memo = genAttrs sinkNames (k: byScope (reduceAt k) (receivers k));
  reduced = mapAttrs (_: mapAttrs (_: x: x.value)) memo;
  reduceErrors = concatMap (k: concatMap (r: memo.${k}.${r.id}.errors) (receivers k)) sinkNames;
in
{
  inherit
    idOf
    reduceAt
    emitted
    receivers
    memo
    reduced
    reduceErrors
    ;
}
