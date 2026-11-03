# The static lib: type constructors, reduce strategies by name, JSON-safe values.
self:
let
  inherit (self._core.types) parseOf;
  # the outer shape only: the elements are walked by the frontier, never here
  outer =
    ok: want: v:
    if ok v then
      { right = v; }
    else
      {
        left = {
          path = [ ];
          got = builtins.typeOf v;
          inherit want;
        };
      };
  # a type record: tagged, with `parse` beside its `check`
  tagged =
    t:
    t
    // {
      __type = true;
      parse = parseOf t;
    };
  inherit (self._core.reduce) reduceNamed;
  inherit (builtins)
    concatStringsSep
    elem
    isAttrs
    isFunction
    isList
    isPath
    mapAttrs
    ;
  # JSON-safe: functions and derivations become strings; toJSON then never fails
  #: lib.jsonSafe :: value -> value -- the value with functions and derivations as strings, so toJSON never fails
  jsonSafe =
    v:
    if isAttrs v && (v.type or null) == "derivation" then
      "<derivation ${v.name or "?"}>"
    else if isFunction v || isAttrs v && v ? __functor then
      "<function>"
    else if isPath v then
      toString v
    else if isList v then
      map jsonSafe v
    else if isAttrs v then
      mapAttrs (_: jsonSafe) v
    else
      v;
in
{
  reduce = reduceNamed;
  #: lib.is :: (v -> bool) -> type -- a type from a check
  is = check: tagged { inherit check; }; # any check is a type: `yen.lib.is builtins.isString`
  #: lib.typed :: name -> (v -> bool) -> type -- a named type from a check: `yen.lib.typed "string" builtins.isString`
  typed = name: check: tagged { inherit name check; }; # the name is what an error states
  #: lib.opt :: type -> default -> type -- the type, with a default when the field has no answer
  opt = t: d: t // { default = d; };
  #: lib.derive :: type -> (instance -> value) -> type -- the type, with a default computed from the instance itself
  derive = t: f: t // { defaultFrom = f; }; # a default computed from the instance itself (Den schema defaults)
  #: lib.maybe :: type -> type -- the type, or null (a maybe-ref is still a ref field)
  maybe = t: {
    __type = true;
    parse = v: if v == null then { right = null; } else parseOf t v; # the element type is checked at the frontier
    default = null;
    __maybe = t; # the type it wraps: a maybe-ref is still a ref (refKind)
  };
  #: lib.listOf :: type -> type -- a list whose elements pass the type; a list of refs is still a ref field
  listOf = t: {
    __type = true;
    parse = outer isList "a list";
    __of = t; # a list of refs is still a ref field: one fact per element (refKind)
  };
  #: lib.kind :: type -- a kind: yen.kinds.<kind>
  kind = {
    check = v: isAttrs v && v ? __kind;
    description = "a kind";
  };
  #: lib.aspect :: type -- an aspect: yen.aspects.<name>
  aspect = {
    check = v: isAttrs v && v ? __aspect;
    description = "an aspect";
  };
  #: lib.enum :: [ value ] -> type -- one of the listed values
  enum = xs: {
    check = v: elem v xs;
    description = "one of ${concatStringsSep ", " (map builtins.toJSON xs)}";
  };
  #: lib.attrsOf :: type -> type -- an attrset whose values pass the type
  attrsOf = t: {
    __type = true;
    parse = outer isAttrs "an attrset";
    description = "an attrset of values its check accepts";
    __values = t; # the value type; the frontier parses each value (parseOf)
  };
  # a secret: checked like t, but no answer (facts, data, scopes, errors, exports) ever states its value, only its
  # sha256; an aspect still reads it
  #: lib.secret :: type -> type -- the type, but every answer states the value only by its sha256
  secret = t: t // { __secret = true; };
  # valid time: an instance with validFrom / validTo (ISO dates) holds at a date the caller passes; no clock in pure eval
  #: lib.validAt :: date -> scope -> bool -- the scope instance holds at the ISO date (validFrom, validTo; absent is open)
  validAt =
    date: s:
    let
      bound = k: d: if (s.${k} or null) == null then d else s.${k};
    in
    bound "validFrom" "0000-00-00" <= date && date <= bound "validTo" "9999-12-31"; # absent or null: open
  inherit jsonSafe;
}
