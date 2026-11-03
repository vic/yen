# An eval part: load: a module is `sources -> sinks` (Cycle). Each key it gives is a sink; each arg is a source
# A part is `_: st:`; `st` is the state of one eval: the names of every part, `root`, and the base helpers.
_: st:
let
  inherit (st)
    all
    attrNames
    b
    concatMap
    declares
    filter
    first
    functionArgs
    genAttrs
    genericClosure
    gives
    isAttrs
    isFunction
    isPath
    isString
    length
    names
    optional
    reduceWith
    root
    ;
  # ── load: a module is `sources -> sinks` (Cycle). Each key it gives is a sink; each arg is a source ──
  # `p0` is a call whose every arg is a sentinel: key names never read a source. `imports` may read a sink
  # that the modules loaded without it give: those sinks come in rounds, reduced from `p0` values only
  sentinel =
    assert false;
    null; # tryEval catches it below; an infinite recursion it would not
  try = x: (b.tryEval x).value;
  spine = p: isAttrs p && b.seq (length (attrNames p) + length (attrNames (p.yen.sinks or { }))) true;
  forced = p: all (i: b.seq i true) (p.imports or [ ]);
  node =
    S: parent: at: key: m:
    let
      file = isPath m || isString m;
      f = if file then import m else m;
      fa = if isFunction f then functionArgs f else { };
      call = s: if isFunction f then f (b.mapAttrs (a: _: s.${a} or sentinel) fa) else f;
      p0 = call { };
      probe = call S;
      k = if file then toString m else key;
    in
    {
      key = k;
      inherit fa parent;
      at = if file then null else at; # an inline module is read again from its parent's real `imports`
    }
    // (
      if !try (spine p0) then
        {
          error = "module ${k}: its keys read an arg";
          fix = "an arg is a source, answered once every module is loaded: read it in a value, not in a key name";
        }
      else if !try (forced probe) then
        {
          error = "module ${k}: `imports` reads an arg that no module gives without it";
          fix = "`imports` can read a sink that other modules give, never `yen` or a sink its own imports give";
        }
      else
        {
          inherit
            f
            p0
            probe
            call
            ;
          importer = !try (forced p0); # its `imports` reads a sink
        }
    );
  closure =
    S:
    genericClosure {
      startSet = [ (node S null null "root" root) ];
      operator =
        n:
        b.genList (
          i:
          node S n.key {
            parent = n.key;
            inherit i;
          } "${n.key}/${toString i}" (b.elemAt n.probe.imports i)
        ) (length (n.probe.imports or [ ]));
    };
  # the sinks of a module set, from `p0` values: they never read a source
  sinksOf =
    F:
    let
      ns = filter (n: n ? p0) F;
    in
    genAttrs (filter (c: c != "yen") (names (concatMap gives ns ++ concatMap declares ns))) (
      c:
      (reduceWith c (first (n: (n.p0.yen.sinks or { }) ? ${c}) ns).p0.yen.sinks.${c} or { } (
        concatMap (
          n:
          optional (n.p0 ? ${c}) {
            from = n.key;
            value = n.p0.${c};
          }
        ) ns
      )).value
    );
  importers = F: length (filter (n: n.importer or false) F);
  # one round per stratum: stop when the keys hold and every importer had its round (or the rounds outgrow the modules)
  rounds =
    r: F:
    let
      F' = closure (sinksOf F);
      same = map (n: n.key) F' == map (n: n.key) F;
    in
    if same && r > importers F' || r > length F' + 1 then
      {
        found = F';
        settled = same;
      }
    else
      rounds (r + 1) F';
  F0 = closure { };
  inherit
    (
      if all (n: !(n ? error)) F0 then
        {
          found = F0;
          settled = true;
        }
      else
        rounds 1 F0
    )
    found
    settled
    ;
in
{
  inherit
    sentinel
    try
    spine
    forced
    node
    closure
    sinksOf
    importers
    rounds
    F0
    found
    settled
    ;
}
