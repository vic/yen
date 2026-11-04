self:
let
  b = builtins;
  inherit (self._uKanren.core) isData walk;
  inherit (self.uKanren)
    conde
    disj
    eq
    fresh
    ;
  # relational lists: nil and cons cells
  #: lib.uKanren.nil :: list -- the empty relational list
  nil = null;
  #: lib.uKanren.cons :: head -> tail -> list -- a relational list cell
  cons = h: t: {
    head = h;
    tail = t;
  };
  #: lib.uKanren.fromList :: [ x ] -> list -- a Nix list as a relational list
  fromList =
    xs:
    b.foldl' (acc: x: cons x acc) nil (b.genList (i: b.elemAt xs (b.length xs - 1 - i)) (b.length xs));
  #: lib.uKanren.toList :: list -> [ x ] -- a relational list as a Nix list
  toList =
    l:
    if l == null then
      [ ]
    else if isData l && l ? head then
      [ l.head ] ++ toList l.tail
    else
      [ l ];
  # l ++ s == out, in every direction (a list of unknown length enumerates without end)
  #: lib.uKanren.appendo :: l -> s -> out -> goal -- l ++ s == out, in every direction
  appendo =
    l: s: out:
    conde [
      [
        (eq l nil)
        (eq s out)
      ]
      [
        (fresh (
          {
            a,
            d,
            r,
          }:
          [
            (eq l (cons a d))
            (eq out (cons a r))
            (appendo d s r)
          ]
        ))
      ]
    ];
  # x is in the list l: a Nix list (known) or a cons list (relational)
  #: lib.uKanren.membero :: x -> l -> goal -- x is in the list l (a Nix list or a relational list)
  membero =
    x: l: st:
    memberIn x l (walk st.s l) st;
  # w: the list as far as it is known now
  memberIn =
    x: l: w:
    if b.isList w then
      disj (map (y: eq x y) w)
    else
      conde [
        [ (fresh ({ d }: eq l (cons x d))) ]
        [
          (fresh (
            { a, d }:
            [
              (eq l (cons a d))
              (membero x d)
            ]
          ))
        ]
      ];
  # a table: each row is a fact; the pattern unifies with a row (attrsets or lists)
  #: lib.uKanren.facto :: [ row ] -> pattern -> goal -- the pattern unifies with one row of the table
  facto = rows: pattern: disj (map (r: eq pattern r) rows);
in
{
  inherit
    nil
    cons
    fromList
    toList
    appendo
    membero
    facto
    ;
}
