#: lib.batteries.docs.kinds :: kinds -> graph -> string -- a markdown table of the kinds: fields, spawns, sinks and scope counts
# a markdown table of the kinds: fields, spawns, sinks, and how many scopes each has in `graph`.
#   docs.kinds yen.kinds yen.lib.graph
self: kinds: graph:
let
  b = builtins;
  names = v: if b.isAttrs v then b.attrNames v else [ ];
  code = xs: b.concatStringsSep ", " (map (x: "`${x}`") xs);
  # d: the definition of kind k
  row = k: d: [
    "`${k}`"
    (code (names (d.fields or { })))
    (code (names (d.spawns or { })))
    (code (names (d.sinks or { })))
    (toString (b.length (b.filter (s: s.kind == k) graph.scopes)))
  ];
in
self.batteries.docs.table [ "Kind" "Fields" "Spawns" "Sinks" "Scopes" ] (
  map (k: row k kinds.${k}) (b.attrNames kinds)
)
