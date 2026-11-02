# yen: one fixpoint, united from the leaves of lib/. Builtins only.
# A leaf is `self: value`, at the attr path of its file: lib/_core/helpers.nix is `_core.helpers`.
# A directory is a nested attrset. A path component starting with `_` is private by convention: the public output is only what the bridge below exposes.
let
  b = builtins;
  stem = n: b.substring 0 (b.stringLength n - 4) n;
  nest = path: v: if path == [ ] then v else { ${b.head path} = nest (b.tail path) v; };
  union =
    a: c:
    a
    // b.mapAttrs (
      k: v:
      if a ? ${k} then
        if b.isAttrs a.${k} && b.isAttrs v then union a.${k} v else b.abort "yen: attr '${k}' defined twice"
      else
        v
    ) c;
  leavesOf =
    path: dir:
    b.concatLists (
      b.attrValues (
        b.mapAttrs (
          n: kind:
          if kind == "directory" then
            leavesOf (path ++ [ n ]) (dir + "/${n}")
          else if b.match ".*\\.nix" n != null then
            [
              {
                inherit path;
                file = dir + "/${n}";
                leaf = path ++ [ (stem n) ];
              }
            ]
          else
            [ ]
        ) (b.readDir dir)
      )
    );
  all = leavesOf [ ] ./lib;
  # a leaf path that is a prefix of another (or equal: duplicate) clashes; both files are named
  clashes = b.filter (
    p:
    p.a.file != p.c.file
    && b.length p.a.leaf <= b.length p.c.leaf
    && b.genList (b.elemAt p.c.leaf) (b.length p.a.leaf) == p.a.leaf
  ) (b.concatMap (a: map (c: { inherit a c; }) all) all);
  leaves =
    if clashes == [ ] then
      all
    else
      b.abort "yen: path clash: ${(b.head clashes).a.file} and ${(b.head clashes).c.file}";
  self = b.foldl' (acc: l: union acc (nest l.leaf (import l.file self))) { } leaves;
in
{
  # the public output is the flat list of lib/api.nix
  lib = self.api;
}
