# An eval part: schema: what a fleet declares, as JSON-safe data (no functions): for agents and docs
# A part is `_: st:`; `st` is the state of one eval: the names of every part, `root`, and the base helpers.
_: st:
let
  inherit (st)
    active
    aspects
    attrNames
    b
    elem
    filesOf
    filter
    instNames
    isAttrs
    isType
    length
    mapAttrs
    refKind
    scopes
    sinkMeta
    top
    typeName
    unsorted
    words
    yen
    ;
  # ── schema: what a fleet declares, as JSON-safe data (no functions): for agents and docs ──
  fieldsOf =
    t:
    if isType t then
      {
        type = typeName t;
      }
      // (if refKind t != null then { ref = refKind t; } else { })
      // (
        if t ? default && elem (b.typeOf t.default) (words "string int bool null list") then
          { default = t.default; }
        else
          { }
      )
      // (if t ? defaultFrom then { derived = true; } else { })
    else if isAttrs t then
      mapAttrs (_: fieldsOf) t
    else
      { type = b.typeOf t; };
  sinkSchema = v: declSchema (if isAttrs v then v else { });
  declSchema = d: {
    reduce = if d ? reduce then d.reduce.name or "custom" else "list";
    of = if d ? of then typeName d.of else null;
    feeds = attrNames (removeAttrs d sinkMeta);
    conditional = d ? at;
  };
  #: result.schema, yen.lib.schema :: { kinds; aspects; invariants; queries; } -- what the fleet declares, as JSON-safe data
  schema = {
    kinds = mapAttrs (k: d: {
      fields = fieldsOf (d.fields or { });
      spawns = attrNames (d.spawns or { });
      sinks = mapAttrs (_: sinkSchema) (d.sinks or { });
      instances = length (instNames k);
      scopes = length (filter (s: s.kind == k) scopes);
    }) (top.kinds or { });
    aspects = mapAttrs (n: a: {
      keys = attrNames (removeAttrs a (words "at order __aspect"));
      cycle = a ? cycle;
      files = filesOf n;
      activeAt = length (filter (s: active.${n}.${s.id}) unsorted);
    }) aspects;
    invariants = attrNames yen.invariants;
    queries = words "errors graph scopes active reduced undefined declaredIn facts check schema flake";
  };
in
{
  inherit
    fieldsOf
    sinkSchema
    schema
    ;
}
