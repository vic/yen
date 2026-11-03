self:
# rdf.nix: an eval result as sorted, de-duplicated N-Triples, and its content hash. Builtins only.
let
  b = builtins;
  base = "https://yen.dev/fleet/";
  bad = [
    "%"
    " "
    "\""
    "<"
    ">"
    "{"
    "}"
    "|"
    "\\"
    "^"
    "`"
    "\n"
    "\r"
    "\t"
  ];
  iriPart = b.replaceStrings bad [
    "%25"
    "%20"
    "%22"
    "%3C"
    "%3E"
    "%7B"
    "%7D"
    "%7C"
    "%5C"
    "%5E"
    "%60"
    "%0A"
    "%0D"
    "%09"
  ];
  iri = ns: x: "<${base}${ns}/${iriPart x}>";
  pred = n: "<${base}yen/${n}>";
  fpred = n: "<${base}field/${iriPart n}>";
  xsd = "http://www.w3.org/2001/XMLSchema#";
  type = "<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>";
  lit =
    s: "\"${b.replaceStrings [ "\\" "\"" "\n" "\r" "\t" ] [ "\\\\" "\\\"" "\\n" "\\r" "\\t" ] s}\"";
  h16 = s: b.substring 0 16 (b.hashString "sha256" s);
  triple =
    s: p: o:
    "${s} ${p} ${o} .";
  parentIn = m: if m == null then [ ] else b.head m;
  parentOf = id: parentIn (b.match "(.*)/[^/]*" id);
  inst = k: n: "<${base}instance/${iriPart k}/${iriPart n}>";
  # a field value as an object: a literal, an instance IRI, or null (no triple)
  fieldObj =
    v:
    if b.isString v then
      lit v
    else if b.isInt v then
      "\"${toString v}\"^^<${xsd}integer>"
    else if b.isBool v then
      "\"${if v then "true" else "false"}\"^^<${xsd}boolean>"
    else if b.isAttrs v && b.isString (v.kind or null) && b.isString (v.name or null) then
      inst v.kind v.name
    else
      null;
  fieldTriple =
    n: k: o:
    if o == null then [ ] else [ (triple n (fpred k) o) ];
  fields =
    n: s:
    b.concatMap (k: fieldTriple n k (fieldObj s.${k})) (
      b.attrNames (removeAttrs s self._core.keys.scopeMeta)
    );
  parentTriple = n: p: if p == [ ] then [ ] else [ (triple n (pred "parent") (iri "scope" p)) ];
  scopeAt =
    n: s:
    [
      (triple n type (iri "kind" s.kind))
      (triple n (pred "name") (lit s.name))
      (triple n (pred "instance") (inst s.kind s.name))
    ]
    ++ fields n s
    ++ parentTriple n (parentOf s.id);
  scopeTriples = s: scopeAt (iri "scope" s.id) s;
  aspectTriples =
    r: a:
    map (id: triple (iri "scope" id) (pred "has") (iri "aspect" a)) (
      b.filter (id: r.active.${a}.${id}) (b.attrNames r.active.${a})
    );
  edgeAt = n: e: [
    (triple n (pred "sink") (lit e.sink))
    (triple n (pred "from") (iri "scope" e.from))
    (triple n (pred "to") (iri "scope" e.to))
    (triple n (pred "origin") (lit e.origin))
  ];
  edgeTriples = e: edgeAt (iri "edge" (h16 "${e.sink}|${e.from}|${e.to}|${e.origin}")) e;
  errorAt = n: e: [
    (triple n (pred "message") (lit e.error))
    (triple n (pred "at") (lit e.from))
  ];
  errorTriples = e: errorAt (iri "error" (h16 "${e.from}|${e.error}")) e;
  # every instance is typed, so a ref field (an instance IRI) meets `sh:class`; data kinds have instances and no scopes
  typed = k: n: [
    (triple (inst k n) type (iri "kind" k))
    (triple (inst k n) (pred "name") (lit n))
  ];
  scopesIn = r: r.scopes or r.graph.scopes; # inside a fleet only the graph is visible
  instanceTriples =
    r:
    b.concatLists (
      b.attrValues (b.mapAttrs (k: ns: b.concatMap (typed k) (b.attrNames ns)) (r.data or { }))
    )
    ++ b.concatMap (s: typed s.kind s.name) (scopesIn r);
  allOf =
    r:
    b.concatMap scopeTriples (scopesIn r)
    ++ instanceTriples r
    ++ b.concatMap (aspectTriples r) (b.attrNames r.active)
    ++ b.concatMap edgeTriples r.graph.edges
    ++ b.concatMap errorTriples r.errors;
  #: lib.rdf.triples :: result -> [ string ] -- the eval result as N-Triples lines, sorted
  triples = r: self._core.helpers.names (allOf r); # sorted, each line once
  textOf = ts: b.concatStringsSep "\n" ts + "\n"; # one N-Triples document
  #: lib.rdf.ntriples :: result -> string -- the eval result as one N-Triples document
  ntriples = r: textOf (triples r);

  # SHACL shapes (Turtle) from r.schema; a leaf field is an attrset with a string `type`.
  kiri = k: "<${base}kind/${iriPart k}>";
  spawnersIn = kinds: k: b.filter (p: b.elem k kinds.${p}.spawns) (b.attrNames kinds);
  isFieldLeaf = f: b.isAttrs f && b.isString (f.type or null);
  leafOf = n: f: if isFieldLeaf f then [ { inherit n f; } ] else [ ];
  leaves = fs: b.concatMap (n: leafOf n fs.${n}) (b.attrNames fs);
  prop = path: extra: "  sh:property [ sh:path ${path} ;${extra} ] ;";
  parentShapeOf =
    ps:
    if b.length ps == 1 then " sh:class ${kiri (b.head ps)} ; sh:maxCount 1 ;" else " sh:maxCount 1 ;";
  fieldShape =
    l:
    prop (fpred l.n) (" sh:maxCount 1 ;" + (if l.f ? ref then " sh:class ${kiri l.f.ref} ;" else ""));
  shape =
    kinds: k:
    b.concatStringsSep "\n" (
      [
        "${kiri k} a sh:NodeShape ;"
        "  sh:targetClass ${kiri k} ;"
        (prop (pred "name") " sh:minCount 1 ; sh:maxCount 1 ; sh:datatype xsd:string ;")
        (prop (pred "parent") (parentShapeOf (spawnersIn kinds k)))
      ]
      ++ map fieldShape (leaves kinds.${k}.fields)
      ++ [ "  ." ]
    );
  shaclOf =
    kinds:
    b.concatStringsSep "\n" (
      [
        "@prefix sh: <http://www.w3.org/ns/shacl#> ."
        "@prefix xsd: <${xsd}> ."
        "@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> ."
        ""
      ]
      ++ map (k: shape kinds k + "\n") (b.filter (k: kinds.${k}.scopes > 0) (b.attrNames kinds))
    );
  #: lib.rdf.shacl :: result -> string -- SHACL shapes (Turtle) from the result schema
  shacl = r: shaclOf r.schema.kinds;
  # the N-Triples of the lines ts, with their content hash and count: the triples are computed once
  shareOf = ts: shareText ts (textOf ts);
  shareText = ts: nt: {
    ntriples = nt;
    sha256 = b.hashString "sha256" nt;
    count = b.length ts;
  };
in
{
  inherit triples ntriples shacl;
  #: lib.rdf.share :: result -> { ntriples; sha256; count; } -- the N-Triples with their content hash and triple count
  share = r: shareOf (triples r);
}
