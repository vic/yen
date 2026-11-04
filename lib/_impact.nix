_:
# Transitive impact of a staged change, as dirty tokens. Builtins only.
# A token is data, never a parsed string: { data = scope id; } (the scope's record), { sink; at; } (the reduced value of
# that sink at that receiver), { instance; name; } (an instance's declared data), { aspect; at; } (where an aspect is active).
let
  b = builtins;
  key = b.toJSON;
  # impactOf :: { edges; whole ? [ ]; seeds; } -> [ token ] -- every token the seeds make dirty, sorted by key
  # edges: [ { out; reads; } ]: `out` is dirty when one of `reads` is; whole: tokens dirty when anything is
  impactOf =
    {
      edges,
      whole ? [ ],
      seeds,
    }:
    impactFrom (readersOf edges) (seeds ++ (if seeds == [ ] then [ ] else whole));
  # the outs that read each token, by its key
  readersOf = b.foldl' (
    acc: e: b.foldl' (a: r: a // { ${key r} = (a.${key r} or [ ]) ++ [ e.out ]; }) acc e.reads
  ) { };
  token = t: {
    key = key t;
    inherit t;
  };
  impactFrom =
    readers: start:
    map (i: i.t) (
      b.sort (x: y: x.key < y.key) (
        b.genericClosure {
          startSet = map token start;
          operator = i: map token (readers.${i.key} or [ ]);
        }
      )
    );
in
{
  inherit impactOf;
}
