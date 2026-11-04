#: lib.batteries.files.toml :: { inline ? ; } -> value -> string -- TOML text from a Nix value
# TOML text from a Nix value, builtins only. Top-level attrsets, and attrsets of attrsets, become [tables] (nested:
# [a.b]); other attrsets are inline tables. `inline` keeps the given table paths inline.
#   files.toml { } { project.name = "app"; profiles.default.API_KEY = { description = "key"; }; }
_:
{
  inline ? [ ],
}:
let
  b = builtins;
  bare = k: b.match "[A-Za-z0-9_-]+" k != null;
  key = k: if bare k then k else b.toJSON k;
  join = b.concatStringsSep;
  value =
    v:
    if b.isAttrs v then
      "{ ${join ", " (map (k: "${key k} = ${value v.${k}}") (b.attrNames v))} }"
    else if b.isList v then
      "[${join ", " (map value v)}]"
    else
      b.toJSON v;
  # a table: its scalar and inline keys first, then its sub-tables
  isTable =
    path: v:
    b.isAttrs v
    && !b.elem (join "." path) inline
    && (b.length path == 1 || b.any b.isAttrs (b.attrValues v));
  table = path: t: tableOf path t (b.filter (k: isTable (path ++ [ k ]) t.${k}) (b.attrNames t));
  # subs: the keys of t that are sub-tables
  tableOf =
    path: t: subs:
    tableWith path t subs (b.filter (k: !b.elem k subs) (b.attrNames t));
  # own: the keys of t that stay in this table
  tableWith =
    path: t: subs: own:
    join "\n" (
      b.filter (s: s != "") (
        [ (headOf path own subs + join "" (map (k: "${key k} = ${value t.${k}}\n") own)) ]
        ++ map (k: table (path ++ [ k ]) t.${k}) subs
      )
    );
  headOf =
    path: own: subs:
    if path == [ ] || own == [ ] && subs != [ ] then "" else "[${join "." (map key path)}]\n";
in
v: table [ ] v
