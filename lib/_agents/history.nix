self:
let
  inherit (self._prelude)
    attrNames
    b
    concatMap
    isAttrs
    length
    names
    ;
  inherit (self._engine) eval;
  # field changes between two `data` answers: [ { path; old; new; } ], sorted by path
  #: lib.diffData :: data -> data -> [ { path; old; new; } ] -- the field changes between two data answers, sorted by path
  diffData = d0: d1: diffAt [ ] d0 d1;
  keysOf = a: c: names (attrNames a ++ attrNames c);
  diffAt =
    p: x: y:
    if isAttrs x && isAttrs y then
      concatMap (k: diffAt (p ++ [ k ]) (x.${k} or null) (y.${k} or null)) (keysOf x y)
    else if x == y then
      [ ]
    else
      [
        {
          path = p;
          old = x;
          new = y;
        }
      ];
  # the fleet at a git revision (transaction time): `module` is the fleet module path inside the repository
  #: lib.asOf :: { url; rev; module; } -> result -- the fleet at a git revision
  asOf =
    {
      url,
      rev,
      module,
    }:
    eval (import ((b.fetchGit { inherit url rev; }) + "/${module}"));
  #: lib.history :: { url; revs; module; } -> [ { rev; errors; scopes; changes; } ] -- the fleet at each revision, with the field changes from the one before
  history =
    {
      url,
      revs,
      module,
    }:
    historyOf revs (b.elemAt (map (rev: asOf { inherit url rev module; }) revs)); # one eval per revision
  # r: the result at the revision of each index
  historyOf =
    revs: r:
    b.genList (i: {
      rev = b.elemAt revs i;
      errors = length (r i).errors;
      scopes = length (r i).scopes;
      changes = if i == 0 then [ ] else diffData (r (i - 1)).data (r i).data;
    }) (length revs);
in
{
  inherit
    diffData
    asOf
    history
    ;
}
