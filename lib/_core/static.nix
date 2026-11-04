# The static lib: type constructors, reduce strategies by name, JSON-safe values.
self:
let
  inherit (self._core.types) checkOf parseOf;
  inherit (self._core.reduce) reduceNamed;
  inherit (builtins)
    all
    attrNames
    concatStringsSep
    elem
    elemAt
    genList
    length
    isAttrs
    isFunction
    isList
    isPath
    isString
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
  boundIn =
    s: k: d:
    if (s.${k} or null) == null then d else s.${k};
in
{
  reduce = reduceNamed;
  #: lib.is :: (v -> bool) -> type -- a type from a check
  is = check: { inherit check; }; # any check is a type: `yen.lib.is builtins.isString`
  #: lib.opt :: type -> default -> type -- the type, with a default when the field has no answer
  opt = t: d: t // { default = d; };
  #: lib.derive :: type -> (instance -> value) -> type -- the type, with a default computed from the instance itself
  derive = t: f: t // { defaultFrom = f; }; # a default computed from the instance itself (Den schema defaults)
  #: lib.maybe :: type -> type -- the type, or null (a maybe-ref is still a ref field)
  maybe = t: {
    check = v: v == null || checkOf t v;
    parse = v: if v == null then { right = v; } else parseOf t v;
    default = null;
    __maybe = t; # the type it wraps: a maybe-ref is still a ref (refKind)
  };
  #: lib.listOf :: type -> type -- a list whose elements pass the type; a list of refs is still a ref field
  listOf = t: {
    check = v: isList v && all (checkOf t) v;
    # the list now, each element later: `genList` forces none of them
    parse =
      v:
      if isList v then
        {
          right = v;
          owe = genList (i: {
            path = [ i ];
            type = t;
            value = elemAt v i;
          }) (length v);
        }
      else
        { left.want = "a list"; };
    __of = t; # a list of refs is still a ref field: one fact per element (refKind)
  };
  # named scalar types: yen's own, with a name for errors. nixpkgs types of the same names check only the outer shape
  # of a composite; these are the types a field or a sink should use
  #: lib.str :: type -- a string
  str = {
    check = isString;
    description = "a string";
  };
  #: lib.int :: type -- an int
  int = {
    check = builtins.isInt;
    description = "an int";
  };
  #: lib.bool :: type -- a bool
  bool = {
    check = builtins.isBool;
    description = "a bool";
  };
  #: lib.port :: type -- a TCP or UDP port: an int from 0 to 65535
  port = {
    check = v: builtins.isInt v && v >= 0 && v <= 65535;
    description = "a port (0 to 65535)";
  };
  #: lib.path :: type -- a path, or a string that starts with /
  path = {
    check = v: isPath v || isString v && builtins.substring 0 1 v == "/";
    description = "a path";
  };
  #: lib.attrs :: type -- any attrset
  attrs = {
    check = isAttrs;
    description = "an attrset";
  };
  #: lib.any :: type -- any value, unchecked: a nixpkgs input, a package set
  any = {
    check = _: true;
    description = "any value";
  };
  #: lib.oneOf :: [ type ] -> type -- a value one of the types accepts
  oneOf = ts: {
    check = v: builtins.any (t: checkOf t v) ts;
    description = "one of: ${
      concatStringsSep ", " (map (t: t.description or "a value its check accepts") ts)
    }";
  };
  #: lib.functionTo :: type -> type -- a function; what it returns is checked where it lands: a typed sink or field
  functionTo = t: {
    check = v: isFunction v || isAttrs v && v ? __functor;
    # a check never calls the function: Nix cannot look inside one, and a call could loop or throw
    parse =
      v:
      if isFunction v || isAttrs v && v ? __functor then
        { right = v; }
      else
        { left.want = "a function"; };
    __to = t; # the type of what it returns, for docs and the schema
    description = "a function";
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
    check = v: isAttrs v && all (checkOf t) (builtins.attrValues v);
    # the attrset now, each value later
    parse =
      v:
      if isAttrs v then
        {
          right = v;
          owe = map (n: {
            path = [ n ];
            type = t;
            value = v.${n};
          }) (attrNames v);
        }
      else
        { left.want = "an attrset"; };
    description = "an attrset of values its check accepts";
  };
  # a secret: checked like t, but no answer (facts, data, scopes, errors, exports) ever states its value, only its
  # sha256; an aspect still reads it
  #: lib.secret :: type -> type -- the type, but every answer states the value only by its sha256
  secret = t: t // { __secret = true; };
  # valid time: an instance with validFrom / validTo (ISO dates) holds at a date the caller passes; no clock in pure eval
  #: lib.validAt :: date -> scope -> bool -- the scope instance holds at the ISO date (validFrom, validTo; absent is open)
  validAt =
    date: s: boundIn s "validFrom" "0000-00-00" <= date && date <= boundIn s "validTo" "9999-12-31"; # absent or null: open
  inherit jsonSafe;
}
