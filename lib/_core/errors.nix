# Error records, and `near`: the known names a typo was probably meant to be. builtins are global.
_:
let
  inherit (builtins) filter foldl';
  err = from: msg: errWith from msg { };
  errWith =
    from: msg: x:
    {
      error = msg;
      inherit from;
      code = "error";
      path = [ ];
      class = "fixable";
    }
    // x;
  unknown =
    from: x: known: e:
    errWith from "no ${builtins.substring 8 99 e.code} ${x}" (e // { near = near x known; }); # code: "unknown-<what>"
  # edit distance (Levenshtein), for `near`: the known names a typo was probably meant to be
  dist =
    a: c:
    let
      n = builtins.stringLength c;
      ch = s: i: builtins.substring i 1 s;
      min = x: y: if x < y then x else y;
      range = builtins.genList (x: x);
      # deletion or insertion (+1), else substitution (+1 unless the characters match)
      cell =
        prev: r: i: j:
        min (min (builtins.elemAt prev (j + 1)) (builtins.elemAt r j) + 1) (
          builtins.elemAt prev j + (if ch a i == ch c j then 0 else 1)
        );
      row = prev: i: foldl' (r: j: r ++ [ (cell prev r i j) ]) [ (i + 1) ] (range n);
    in
    builtins.elemAt (foldl' row (range (n + 1)) (range (builtins.stringLength a))) n;
  near =
    x: cs:
    map (p: p.c) (
      builtins.sort (p: q: p.d < q.d || p.d == q.d && p.c < q.c) (
        filter (p: p.d <= 2 && p.d < builtins.stringLength x) (
          map (c: {
            inherit c;
            d = dist x c;
          }) cs
        )
      )
    );
in
{
  inherit
    err
    errWith
    unknown
    dist
    near
    ;
}
