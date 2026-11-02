# Pure helpers of the engine: lists, attrsets, rule literals, currying. Builtins only; builtins are global.
_:
let
  inherit (builtins)
    attrNames
    elem
    filter
    foldl'
    head
    isAttrs
    isList
    isString
    length
    listToAttrs
    ;
  # ── tiny helpers (no nixpkgs) ──
  toList = v: if isList v then v else [ v ];
  first = p: foldl' (a: x: if a == null && p x then x else a) null; # stops calling p at the first hit
  uniq = foldl' (acc: x: if elem x acc then acc else acc ++ [ x ]) [ ];
  genAttrs =
    xs: f:
    listToAttrs (
      map (n: {
        name = n;
        value = f n;
      }) xs
    );
  keySet = xs: genAttrs xs (_: true);
  names = xs: attrNames (keySet xs); # sorted, no duplicates
  nest = path: v: if path == [ ] then v else { ${head path} = nest (builtins.tail path) v; };
  orNull = x: if x == null then [ ] else [ x ];
  optional = c: x: if c then [ x ] else [ ];
  words = s: filter isString (builtins.split " " s); # "a b" is [ "a" "b" ]
  isRef = v: isAttrs v && v ? kind && v ? name; # an instance, or a ref to one
  lit = atom: {
    inherit atom;
    join = [ ];
  }; # a rule literal: its atom, and the atoms that bind its own `#` variables
  curried =
    n: f: acc:
    if length acc == n then f acc else x: curried n f (acc ++ [ x ]); # n arguments, one at a time
  combinators = words "all not within has"; # `lib.all ps` is { __all = ps; }, and so on
in
{
  inherit
    toList
    first
    uniq
    genAttrs
    keySet
    names
    nest
    orNull
    optional
    words
    isRef
    lit
    curried
    combinators
    ;
}
