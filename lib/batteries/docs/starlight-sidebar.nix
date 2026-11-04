#: lib.batteries.docs.starlight-sidebar :: { from; } -> files value -- src/sidebar.json from the entries of the sink from
# The value of the `files` key of the sink `from`, which `starlight-page` gives entries to (reduce `list`). The sections
# in order, the pages of each in order; the home page (route `index`) is the splash, not in the sidebar. An entry has
# `section` (a scope with `name`, `title` and `order`), `order` and `item`.
#   yen.kinds.site.sinks.sidebar = { reduce = yen.lib.reduce.list; files = starlight-sidebar { from = yen.kinds.site.sinks.sidebar; }; };
_:
{ from }:
{ sinks, ... }:
let
  b = builtins;
  byOrder = p: q: p.order < q.order;
  shown = b.filter (e: e.item.slug != "index") sinks.${from.__sink};
  bySection = b.groupBy (e: e.section.name) shown;
  sections = b.sort byOrder (map (es: (b.head es).section) (b.attrValues bySection));
in
{
  files.file."src/sidebar.json".text =
    b.toJSON (
      map (s: {
        label = s.title;
        items = map (e: e.item) (b.sort byOrder bySection.${s.name});
      }) sections
    )
    + "\n";
}
