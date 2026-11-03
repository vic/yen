# ── reduce strategies: elements in, { value; errors; } out ──
self:
let
  inherit (builtins)
    attrValues
    concatMap
    concatStringsSep
    foldl'
    head
    isList
    length
    mapAttrs
    ;
  inherit (self._core.helpers) uniq optional;
  inherit (self._core.types) isLeaf;
  inherit (self._core.errors) errWith;
  pure = value: {
    inherit value;
    errors = [ ];
  };
  # the merge of one key of bv into a: a new key as is, a leaf clash is an error unless equal, two attrsets recurse
  mergeKey =
    path: a: n: v:
    if !(a ? ${n}) then
      pure v
    else if isLeaf a.${n} || isLeaf v then
      {
        value = a.${n};
        errors = optional (a.${n} != v) (
          errWith "merge" "merge conflict at ${concatStringsSep "." (path ++ [ n ])}" {
            code = "merge";
            path = path ++ [ n ];
          }
        );
      }
    else
      mergeAt (path ++ [ n ]) a.${n} v;
  mergeSubs = a: subs: {
    value = a // mapAttrs (_: x: x.value) subs;
    errors = concatMap (x: x.errors) (attrValues subs);
  };
  mergeAt =
    path: a: bv:
    mergeSubs a (mapAttrs (mergeKey path a) bv);
  mergeStep =
    acc: m:
    m
    // {
      errors = acc.errors ++ m.errors;
    };
  reduce = {
    #: lib.reduce.list :: [ element ] -> { value = [ v ]; errors; } -- every element value, in the order the elements arrive
    list = es: pure (map (e: e.value) es);
    #: lib.reduce.set :: [ element ] -> { value = [ v ]; errors; } -- the element values without duplicates
    set = es: pure (uniq (map (e: e.value) es));
    #: lib.reduce.flat :: [ element ] -> { value = [ v ]; errors; } -- the element values joined: a list element gives its items, any other value itself; without duplicates, in first-seen order
    flat = es: pure (uniq (concatMap (e: if isList e.value then e.value else [ e.value ]) es));
    #: lib.reduce.one :: [ element ] -> { value; errors; } -- the one element value; zero or two or more elements is the error one
    one = es: {
      value = if es == [ ] then null else (head es).value;
      errors = optional (length es != 1) (
        errWith "one" "one: got ${toString (length es)} elements" {
          code = "one";
          got = length es;
          want = 1;
        }
      );
    };
    #: lib.reduce.merge :: [ element ] -> { value = attrs; errors; } -- the element values merged as attrsets; two different answers at one path are an error
    merge = foldl' (acc: e: mergeStep acc (mergeAt [ ] acc.value e.value)) (pure { });
    #: lib.reduce.elements :: [ element ] -> { value = [ element ]; errors; } -- the elements themselves, each with its value and where it came from
    elements = pure;
  };
  # each built-in reduce is callable and carries its name, so `schema` can say which strategy a sink uses
  reduceNamed = mapAttrs (n: f: {
    __functor = _: f;
    name = n;
  }) reduce;
in
{
  inherit
    mergeAt
    pure
    reduce
    reduceNamed
    ;
}
