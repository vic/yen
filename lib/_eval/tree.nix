# An eval part: the scope tree: nested cycles. key = what the parent spawned; identity = keys from the root
# A part is `_: st:`; `st` is the state of one eval: the names of every part, `root`, and the base helpers.
_: st:
let
  inherit (st)
    any
    attrNames
    childId
    concatMap
    concatStringsSep
    elem
    errWith
    filter
    fix
    genericClosure
    groupBy
    here
    instances
    instNames
    isAttrs
    isString
    kindAt
    kindIds
    kindNames
    kinds
    leafOf
    mapAttrs
    ;
  # ── the scope tree: nested cycles. key = what the parent spawned; identity = keys from the root ──
  mkScope =
    parent: kind: name: inst:
    fix (
      s:
      inst
      // {
        inherit kind name parent;
        key = "${leafOf kind}:${name}"; # the parent in `path` keeps a nested key unique
        path = (if parent == null then [ ] else parent.path) ++ [ s.key ];
        __here = here s;
        id = concatStringsSep "/" s.path;
        up = (if parent == null then [ ] else parent.up) ++ [ s ];
        rup = [ s ] ++ (if parent == null then [ ] else parent.rup);
      }
    ); # rup: nearest first, built once
  # a nested kind is spawned from its parent's data by default; an explicit `spawns.<c>` replaces the default
  spawnsOf =
    k:
    mapAttrs (
      c: _: s:
      s.${c} or { }
    ) ((kindAt k).kinds or { })
    // (kindAt k).spawns or { };
  spawned = concatMap (k: filter (c: isString (childId k c)) (attrNames (spawnsOf k))) kindIds;
  roots = concatMap (k: map (n: mkScope null k n instances.${k}.${n}) (instNames k)) (
    filter (k: (kinds.${k} ? spawns || kinds.${k} ? kinds) && !elem k spawned) kindNames
  );
  childrenOf =
    s: concatMap (c: childrenMade s c ((spawnsOf s.kind).${c} s)) (attrNames (spawnsOf s.kind));
  # made: what spawns.<c> gives for scope s
  childrenMade =
    s: c: made:
    if !isAttrs made then
      [ (errWith s.id "spawns.${c} gives no attrset" { code = "spawns"; }) ]
    else
      map (
        n:
        if any (x: x.key == "${c}:${n}") s.up then
          errWith s.id "instance ${c}:${n} twice on path" {
            code = "cycle";
            got = "${c}:${n}";
          }
        else if !isAttrs made.${n} then
          errWith s.id "spawns.${c}.${n} is no attrset" { code = "spawns"; }
        else
          mkScope s (childId s.kind c) n made.${n}
      ) (attrNames made);
  item =
    c:
    if c ? error then
      {
        key = "error:${c.from}:${c.error}";
        e = c;
      }
    else
      {
        key = c.id;
        s = c;
      };
  tree = genericClosure {
    # C-level loop, breadth first: a parent comes before its children
    startSet = map item roots;
    operator = i: if i ? s then map item (childrenOf i.s) else [ ];
  };
  unsorted = map (i: i.s) (filter (i: i ? s) tree);
  treeErrors = map (i: i.e) (filter (i: i ? e) tree);
  parentId = s: if s.parent == null then "" else s.parent.id;
  byParent = groupBy parentId unsorted;
  below = s: byParent.${s.id} or [ ];

in
{
  inherit
    mkScope
    spawnsOf
    spawned
    roots
    childrenOf
    item
    tree
    unsorted
    treeErrors
    parentId
    byParent
    below
    ;
}
