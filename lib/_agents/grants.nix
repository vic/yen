self:
let
  inherit (self._prelude)
    all
    any
    b
    concatMap
    elem
    filter
    isAttrs
    isList
    isRef
    length
    uniq
    ;
  # grants that only narrow, by reference. A scope entry is a path [ { kind; name; } … ] (its scope and the scopes under
  # it) or an instance (every scope whose path holds it, and the scopes under them). A sink is a ref or { sink; }.
  # Identities hold only strings, so they compare as data. Two grants meet entry by entry: the deeper path when one
  # path holds the other, else both must hold ({ all }). There is no way to widen; a non-ref entry covers nothing.
  ident = x: { inherit (x) kind name; };
  entryOf =
    t:
    if isList t && t != [ ] && all isRef t then
      { path = map ident t; }
    else if isRef t then
      { instance = ident t; }
    else
      { invalid = t; };
  prefixOf = p: s: length p <= length s && b.genList (b.elemAt s) (length p) == p;
  covers =
    e: s:
    if e ? path then
      prefixOf e.path s
    else if e ? instance then
      elem e.instance s
    else if e ? all then
      all (x: covers x s) e.all
    else
      false;
  meet =
    e: f:
    if e ? invalid || f ? invalid then
      [ ]
    else if e == f then
      [ e ]
    else if e ? path && f ? path then
      if prefixOf e.path f.path then
        [ f ]
      else if prefixOf f.path e.path then
        [ e ]
      else
        [ ]
    else if e ? path && covers f e.path then
      [ e ]
    else if f ? path && covers e f.path then
      [ f ]
    else
      [
        {
          all = [
            e
            f
          ];
        }
      ];
  sinkOf = k: if isAttrs k then k.__sink or k.sink or null else null;
  grants = {
    #: lib.grant :: { scopes; sinks ? null; } -> grant -- where a change may reach, by reference: scope paths or instances, sink refs (null: every sink)
    grant =
      {
        scopes,
        sinks ? null,
      }:
      {
        scopes = map entryOf scopes;
        sinks = if sinks == null then null else map sinkOf sinks;
      };
    #: lib.narrow :: grant -> grant -> grant -- two grants met: the scopes both cover, the sinks both allow; never wider
    narrow = g: h: {
      scopes = uniq (concatMap (e: concatMap (meet e) h.scopes) g.scopes);
      sinks =
        if g.sinks == null then
          h.sinks
        else if h.sinks == null then
          g.sinks
        else
          filter (x: elem x h.sinks) g.sinks;
    };
    #: lib.allowed :: grant -> { to; sink; } -> bool -- the grant covers the scope path `to` and the sink (a ref or { sink; })
    allowed =
      g: e:
      any (p: covers p (map ident e.to)) g.scopes && (g.sinks == null || elem (sinkOf e.sink) g.sinks);
  };
in
{
  inherit
    ident
    entryOf
    prefixOf
    covers
    meet
    sinkOf
    grants
    ;
}
