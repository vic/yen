# An eval part: instance data: typed paths. Answers first, then the type defaults; a failed check reads as null
# A part is `_: st:`; `st` is the state of one eval: the names of every part, `root`, and the base helpers.
_: st:
let
  inherit (st)
    all
    answers
    any
    aspects
    attrNames
    attrsIn
    b
    boolCheck
    concatMap
    concatStringsSep
    declPath
    elem
    errWith
    factLits
    filter
    first
    foldl'
    genAttrs
    head
    hide
    idAt
    isAttrs
    isFunction
    isLeaf
    isList
    isSecret
    isType
    kindAt
    kindRef
    kinds
    labelTable
    length
    lib
    mapAttrs
    names
    near
    nestedRef
    ownedKeys
    parseOf
    pure
    refKind
    relations
    renderId
    toList
    top
    topRefs
    typeName
    words
    ;
  # ── instance data: typed paths. Answers first, then the type defaults; a failed check reads as null ──
  typesAt = k: path: answers (declPath k ++ [ "fields" ] ++ path);
  # the fields of a kind whose type is secret, and a field value as an answer may state it
  secretFields = k: filter (f: any isSecret (typesAt k [ f ])) (attrNames ((kindAt k).fields or { }));
  shown =
    k: f: v:
    if !(elem f (secretFields k)) || v == null then
      v
    else if isList v then
      map hide v
    else
      hide v;
  # one walk per instance path gives its value and its errors; `at` is the data path of the instance,
  # [ k n ] at the top, the parent's `at` ++ [ c n ] for an instance of the nested kind c
  inst =
    k: at: path:
    let
      ts = typesAt k path;
      tys = filter isType ts;
      hits = answers (at ++ path);
      d = first (t: isAttrs t && (t ? default || t ? defaultFrom)) ts;
      r =
        if hits != [ ] then
          { ok = head hits; }
        else if d != null then
          {
            ok =
              if d ? defaultFrom then
                d.defaultFrom (
                  foldl' (v: s: v.${s}) instances at
                  // {
                    kind = k;
                    name = b.elemAt at (length at - 1);
                  }
                )
              else
                d.default;
          }
        else
          { };
      id = idAt at;
      p = concatStringsSep "." path;
      bad = first (t: parseOf t r.ok ? left) tys;
      notBool = first (t: !boolCheck t r.ok) tys;
      kr = first (t: refKind t != null) tys;
      fail = e: {
        value = null;
        # a nested instance is named by its whole data path; a top instance keeps the field path
        errors = [
          (errWith id e.error (
            removeAttrs e [ "error" ] // { path = (if length at > 2 then at else [ ]) ++ path; }
          ))
        ];
      };
      # a key that names a nested kind holds its instances, keyed by name, each typed by that kind
      sub = genAttrs (names (attrsIn (hits ++ ts))) (
        f:
        if path == [ ] && (kindAt k).kinds or { } ? ${f} then
          setOr [ f ] "write ${f}.<name> = { ... }" (
            collect (
              genAttrs (names (attrsIn (answers (at ++ [ f ])))) (
                m:
                setOr
                  [
                    f
                    m
                  ]
                  "write ${f}.${m} = { ... }"
                  (
                    inst (toList k ++ [ f ]) (
                      at
                      ++ [
                        f
                        m
                      ]
                    ) [ ]
                  )
              )
            )
          )
        else
          inst k at (path ++ [ f ])
      );
      # a nested group or member that is not an attrset is an error, never a lost value
      setOr =
        ps: fix: x:
        if all (v: isAttrs v && !isLeaf v) (answers (at ++ ps)) then
          x
        else
          {
            value = { };
            errors = [
              (errWith (idAt (at ++ ps)) "${concatStringsSep "." ps} is not an attrset" {
                code = "check";
                path = at ++ ps;
                got = b.typeOf (first (v: !isAttrs v || isLeaf v) (answers (at ++ ps)));
                want = "attrset";
                inherit fix;
              })
            ];
          };
      collect = xs: {
        value = mapAttrs (_: x: x.value) xs;
        errors = concatMap (x: x.errors) (b.attrValues xs);
      };
    in
    if tys != [ ] && !(r ? ok) then
      fail {
        error = "missing ${p}";
        code = "missing";
        want = typeName (head tys);
        fix = "set ${id}.${p}";
      }
    else if tys != [ ] && notBool != null then
      fail {
        error = "the check of ${p} gives a ${b.typeOf (notBool.check r.ok)}, not a bool";
        code = "check-not-bool";
        want = typeName notBool;
        fix = "make the check `v: bool`; a curried check needs its other argument first";
      }
    else if kr != null && isList (refKind kr) then
      fail (nestedRef id "ref" (refKind kr))
    else if tys != [ ] && bad != null then
      fail {
        error = if kr != null then "${p} wants a ${refKind kr} ref" else "${p} fails its check";
        code = if kr != null then "ref" else "check";
        got =
          if any isSecret tys then
            hide r.ok
          else if isFunction r.ok then
            "<function>"
          else
            r.ok;
        want = typeName bad;
        fix =
          if kr != null then
            "use yen.${refKind kr}.<name>, not a string"
          else
            "give ${p} a value of type ${typeName bad}";
      }
    else if tys != [ ] then
      pure r.ok
    else if path != [ ] && ts == [ ] then
      fail {
        error = "unknown field ${p}";
        code = "unknown-field";
        near = near (b.elemAt path (length path - 1)) (
          names (attrsIn (typesAt k (b.genList (b.elemAt path) (length path - 1))))
        );
        fix = "declare yen.kinds.${renderId k}.fields.${p}, or use a declared field";
      }
    else
      collect sub;
  instNames = k: attrNames (top.${k} or { });
  instances = mapAttrs (
    k: _:
    genAttrs (instNames k) (
      n:
      (inst k
        [
          k
          n
        ]
        [ ]
      ).value
      // {
        kind = k;
        name = n;
      }
    )
  ) kinds;
  # the owned aspects (key `[ …owner "aspects" a ]`), grouped by the owner's path: one parse per key
  ownedIndex = b.groupBy (x: b.toJSON x.owner) (
    map (
      key:
      let
        p = ownedKeys.${key};
      in
      {
        inherit key;
        owner = b.genList (b.elemAt p) (length p - 2);
        name = b.elemAt p (length p - 1);
      }
    ) (attrNames ownedKeys)
  );
  # the aspects an owner (an instance `[ k n ]`, a kind `[ "kinds" k … ]`) owns, as `{ aspects.<a> = ref; }`, or { }
  ownedBy =
    refs: owner:
    let
      own = ownedIndex.${b.toJSON owner} or [ ];
    in
    if own == [ ] then
      { }
    else
      {
        aspects = b.listToAttrs (
          map (x: {
            inherit (x) name;
            value = refs.${x.key};
          }) own
        );
      };
  yen =
    mapAttrs (
      k:
      mapAttrs (
        n: i:
        i
        // ownedBy aspects [
          k
          n
        ]
      )
    ) instances
    // {
      inherit kinds aspects lib;
      helpers = top.helpers or { };
      queries = top.queries or { };
      invariants = top.invariants or { };
      inherit relations; # user relations a rule derives: `<name>.arity`, called by reference
      facts = factLits; # rule literals by reference
      inherit labelTable;
    }; # declarations an agent or the docs read
  # the `yen` aspects and kind sinks get: an instance is a ref, its fields are not readable; no structure queries.
  # A value reads the fleet only through its args and cycle `tree` requests, so every read is an edge.
  refsYen =
    yen
    // mapAttrs (
      k: _:
      genAttrs (instNames k) (
        n:
        {
          kind = k;
          name = n;
        }
        # #87: the aspects the instance owns, as refs: `yen.kit.sshd.aspects.server`
        // ownedBy refsYen.aspects [
          k
          n
        ]
        // mapAttrs (
          f: _:
          throw "yen.${k}.${n}.${f}: an aspect reads instance data only through its args: take `${k}` as an arg, or follow a ref field of an arg"
        ) (kinds.${k}.fields or { })
      )
    ) kinds
    // {
      lib =
        lib
        // genAttrs (words "graph scopesOf children declaredIn labels floor") (
          q:
          throw "yen.lib.${q}: an aspect reads the fleet only through its args: ask the cycle `tree` for it"
        );
      helpers = topRefs.helpers or { };
      # a kind, a sink and an aspect are refs here: another declaration's content is no read an edge can record
      kinds = mapAttrs (_: kindRef) kinds;
      aspects = mapAttrs (
        n: a:
        {
          __aspect = n;
        }
        // mapAttrs (
          k: _:
          throw "yen.aspects.${n}.${k}: an aspect reads another aspect only as a ref: put shared code in yen.helpers"
        ) (removeAttrs a [ "__aspect" ])
      ) aspects;
    };

in
{
  inherit
    typesAt
    secretFields
    shown
    inst
    instNames
    instances
    ownedIndex
    ownedBy
    yen
    refsYen
    ;
}
