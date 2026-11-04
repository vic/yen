#: lib.batteries.mermaid.kinds :: kinds -> view -- spawns between kinds, and fields that refer to a kind
# a view of the kinds: a solid edge is `spawns` (parent kind to child kind), a dotted edge a field that refers to a kind
#   mermaid.flowchart { } (mermaid.kinds yen.kinds)
self: kinds:
let
  b = builtins;
  inherit (self._core.helpers) renderId;
  names = v: if b.isAttrs v then b.attrNames v else [ ];
  # d: the definition of kind k
  kindEdges =
    k: d:
    map (c: {
      from = "k:${k}";
      to = "k:${c}";
    }) (names (d.spawns or { }))
    ++ b.concatMap (f: fieldEdge k f d.fields.${f}) (names (d.fields or { }));
  # t: the type of field f of kind k
  fieldEdge =
    k: f: t:
    if b.isAttrs t && (t ? __kind || t ? __maybe && t.__maybe ? __kind) then
      [
        {
          from = "k:${k}";
          to = "k:${renderId (t.__kind or t.__maybe.__kind)}";
          label = f;
          live = false;
        }
      ]
    else
      [ ];
in
{
  nodes = map (k: {
    id = "k:${k}";
    label = k;
    kind = "kind";
  }) (b.attrNames kinds);
  edges = b.concatLists (map (k: kindEdges k kinds.${k}) (b.attrNames kinds));
}
