# An eval part: modules as a graph: what each module asks, gives, declares and imports. An import loop is a cycle
# A part is `_: st:`; `st` is the state of one eval: the names of every part, `root`, and the base helpers.
_: st:
let
  inherit (st)
    any
    attrNames
    b
    concatMap
    elem
    errWith
    filter
    first
    foldl'
    found
    genAttrs
    graphs
    head
    intersectAttrs
    isAttrs
    isFunction
    keySet
    listToAttrs
    mapAttrs
    optional
    parseOf
    reduce
    settled
    yen
    yenKeys
    ;
  # ── modules as a graph: what each module asks, gives, declares and imports. An import loop is a cycle ──
  # edges are "depends on": an importer on the sinks it asks (its declared args, as for aspects), a sink on
  # the modules that give or declare it, a module on the module that imports it
  ok0 = filter (n: n ? p0) found;
  sinkNode = c: "sink:${c}";
  #: result.modules :: { key = { parent; asks; gives; declares; importer; }; } -- every module, as the loader sees it
  modules = listToAttrs (
    map (n: {
      name = n.key;
      value = {
        inherit (n) parent;
        asks = attrNames n.fa;
        gives = if n ? p0 then gives n else [ ];
        declares = if n ? p0 then declares n else [ ];
        importer = n.importer or false;
      };
    }) found
  );
  moduleGraph = graphs.fromEdges (
    concatMap (
      n:
      optional (n.parent != null) {
        from = n.key;
        to = n.parent;
      }
    ) found
    ++ concatMap (
      n:
      map (c: {
        from = n.key;
        to = sinkNode c;
      }) (filter (c: roundNames ? ${c}) (attrNames n.fa))
    ) (filter (n: n.importer or false) found)
    ++ concatMap (
      n:
      map (c: {
        from = sinkNode c;
        to = n.key;
      }) (gives n ++ declares n)
    ) ok0
  );
  roundNames = removeAttrs (keySet (concatMap gives ok0 ++ concatMap declares ok0)) [ "yen" ]; # `yen` never answers `imports`
  onCycle = keySet (graphs.cycles moduleGraph);
  # the importers on a cycle; when the rounds never settle, every importer
  looping = keySet (
    map (n: n.key) (filter (n: (n.importer or false) && (!settled || onCycle ? ${n.key})) found)
  );
  moduleAbove = n: graphs.reach (mapAttrs (_: m: optional (m.parent != null) m.parent) modules) n.key;
  # the sinks some module gives or declares in `yen.sinks` (`yen` always); a declared sink counts as read
  gives = n: filter (c: c != "imports") (attrNames n.p0);
  declares = n: attrNames (n.p0.yen.sinks or { });
  probed = filter (n: n ? p0) found;
  moduleSinks = keySet ([ "yen" ] ++ concatMap gives probed ++ concatMap declares probed);
  asked = keySet ([ "yen" ] ++ concatMap (n: attrNames n.fa) found ++ concatMap declares probed);
  used = keySet (concatMap gives probed ++ concatMap (n: attrNames n.fa) found); # a sink reduces only where it is given or read
  # a source: its sink reduced like a kind sink. `of` checks each module's value; `reduce` defaults to `one`
  source = y: c: if c == "yen" then y else (reduceModules c).value;
  # the givers and the declaration come from the module key sets: a sink never waits on every module (`top`)
  reduceModules =
    c:
    let
      ms = filter (n: real.${n.key} ? mod) ok0;
      decl = first (n: (n.p0.yen.sinks or { }) ? ${c}) ms;
    in
    reduceWith c (if decl == null then { } else real.${decl.key}.mod.yen.sinks.${c}) (
      map (n: {
        from = n.key;
        value = real.${n.key}.mod.${c};
      }) (filter (n: n.p0 ? ${c}) ms)
    );
  reduceWith =
    c: d: es:
    let
      # the frontier decides the shape only; the parts it owes are checked by `result.deep`
      okOf = e: !(d ? of) || parseOf d.of e.value ? right;
      red = (d.reduce or reduce.one) (filter okOf es);
    in
    {
      inherit (red) value;
      # the parts `of` did not force, for `result.deep`
      owe =
        if d ? of then
          concatMap (
            e:
            map (
              o:
              o
              // {
                path = [ c ] ++ o.path;
                inherit (e) from;
              }
            ) ((parseOf d.of e.value).owe or [ ])
          ) (filter okOf es)
        else
          [ ];
      errors =
        map (
          e:
          errWith e.from "sink ${c}: the value of ${e.from} fails `of`" {
            code = "of";
            path = [ c ];
          }
        ) (filter (e: !okOf e) es)
        ++ map (
          e:
          e
          // {
            from = "modules";
            sink = c;
          }
        ) red.errors;
    };
  real = realWith yen;
  # two loads: `yen` with instance data answers data and spawns; aspects and kind sinks get instances as refs
  realWith =
    y:
    let
      r = listToAttrs (
        map (n: {
          name = n.key;
          value = load y r n;
        }) found
      );
    in
    r;
  load =
    y: r: n:
    let
      parent = if n.at or null == null then null else r.${n.at.parent};
      f = if parent == null then n.f else b.elemAt parent.mod.imports n.at.i;
      missing = filter (a: !n.fa.${a} && !(moduleSinks ? ${a})) (attrNames n.fa);
    in
    if !(n ? probe) then
      n
    else if looping ? ${n.key} then
      {
        inherit (n) key;
        error = "module ${n.key}: `imports` reads a sink that its own imports give";
        fix = "give the sinks that `imports` reads from modules outside its own imports";
        code = "import-loop";
        path = filter (c: roundNames ? ${c}) (attrNames n.fa);
      }
    else if parent != null && !(parent ? mod) || any (a: looping ? ${a}) (moduleAbove n) then
      { inherit (n) key; } # it goes with its parent, which has the error
    else if missing != [ ] then
      {
        inherit (n) key;
        error = "module ${n.key}: arg `${head missing}` has no answer";
        fix = "a module must give `${head missing}`, or give the arg a default";
      }
    else
      {
        inherit (n) key;
        mod =
          if isFunction f then
            f (genAttrs (filter (a: moduleSinks ? ${a}) (attrNames n.fa)) (source y))
          else
            f;
      };
  loadWith =
    y:
    let
      r = realWith y;
    in
    map (n: r.${n.key}) found;
  loaded = map (n: real.${n.key}) found;
  # an aspect an instance or a kind owns is named by its declaration path under `yen`, as a nested kind is:
  # `[ "kit" "disko" "aspects" "default" ]`, `[ "kinds" "host" "aspects" "web" ]`. Its key is the path's toJSON;
  # a name a fleet gives in `yen.aspects` never starts with `[` (reserved), so no key is shared (#87)
  ownAspects = y: (hoistOf y).y;
  # one module's `yen`: `owned` the aspects its instances and kinds own, `y` the value with them hoisted
  hoistOf =
    y:
    let
      ks = filter (k: !(elem k yenKeys) && isAttrs y.${k}) (attrNames y);
      asp =
        path: d:
        if isAttrs d && isAttrs (d.aspects or null) then
          map (a: {
            name = b.toJSON (
              path
              ++ [
                "aspects"
                a
              ]
            );
            value = d.aspects.${a};
          }) (filter (a: isAttrs d.aspects.${a}) (attrNames d.aspects))
        else
          [ ];
      inst = concatMap (k: concatMap (n: asp [ k n ] y.${k}.${n}) (attrNames y.${k})) ks;
      # a kind and its nested kinds, at every depth
      kindAsp =
        path: d:
        asp path d
        ++ (
          if isAttrs d && isAttrs (d.kinds or null) then
            concatMap (
              c:
              kindAsp (
                path
                ++ [
                  "kinds"
                  c
                ]
              ) d.kinds.${c}
            ) (attrNames d.kinds)
          else
            [ ]
        );
      kindOwned =
        if isAttrs (y.kinds or null) then
          concatMap (k: kindAsp [ "kinds" k ] y.kinds.${k}) (attrNames y.kinds)
        else
          [ ];
      # strip only what is hoisted: an `aspects` or an aspect that is no attrset stays, so its error is reported
      noAspects =
        v:
        if !isAttrs v || !isAttrs (v.aspects or null) then
          v
        else
          let
            bad = b.listToAttrs (
              map (a: {
                name = a;
                value = v.aspects.${a};
              }) (filter (a: !isAttrs v.aspects.${a}) (attrNames v.aspects))
            );
          in
          if bad == { } then removeAttrs v [ "aspects" ] else v // { aspects = bad; };
      strip =
        d:
        if !isAttrs d then
          d
        else
          noAspects d
          // (if isAttrs (d.kinds or null) then { kinds = mapAttrs (_: strip) d.kinds; } else { });
      owned = if isAttrs y then inst ++ kindOwned else [ ];
    in
    {
      inherit owned;
      y =
        if owned == [ ] then
          y
        else
          mapAttrs (
            k: v:
            if k == "kinds" && isAttrs v then
              mapAttrs (_: strip) v
            else if elem k ks then
              mapAttrs (_: noAspects) v
            else
              v
          ) y
          // {
            aspects = (y.aspects or { }) // b.listToAttrs owned;
          };
    };
  # the keys of every owned aspect, from the hoist only: a name a fleet gives is never parsed as a key
  ownedKeys = b.listToAttrs (
    concatMap (
      n:
      map (x: {
        inherit (x) name;
        value = b.fromJSON x.name;
      }) (hoistOf (n.mod.yen or { })).owned
    ) (filter (n: n ? mod) loaded)
  );
  defsOf = l: map (n: ownAspects (n.mod.yen or { })) (filter (n: n ? mod) l);
  # each loaded module's `yen`, its instances' aspects hoisted: what declaredIn reads, once per module
  hoisted = b.listToAttrs (
    map (n: {
      name = n.key;
      value = ownAspects (n.mod.yen or { });
    }) (filter (n: n ? mod) loaded)
  );
  # the modules (file paths, or positions for inline modules) that answer a declaration path, in file order
  #: result.declaredIn, yen.lib.declaredIn :: [ name ] -> [ file ] -- the modules that answer a declaration path, in file order
  declaredIn =
    path:
    map (n: n.key) (
      filter (
        n:
        n ? mod
        &&
          (foldl' (a: k: if a != null && isAttrs a && a ? ${k} then a.${k} else null) hoisted.${n.key} path)
          != null
      ) loaded
    );
  filesOf =
    n:
    declaredIn [
      "aspects"
      n
    ];
  loadErrors = map (
    n:
    errWith "module" n.error (
      {
        code = "module";
      }
      // intersectAttrs {
        fix = 0;
        code = 0;
        path = 0;
      } n
    )
  ) (filter (n: n ? error) loaded);

in
{
  inherit
    ok0
    sinkNode
    modules
    moduleGraph
    roundNames
    onCycle
    looping
    moduleAbove
    gives
    declares
    probed
    moduleSinks
    asked
    used
    source
    reduceModules
    reduceWith
    real
    realWith
    load
    loadWith
    loaded
    ownAspects
    hoistOf
    ownedKeys
    defsOf
    hoisted
    declaredIn
    filesOf
    loadErrors
    ;
}
