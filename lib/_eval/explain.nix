# An eval part: explain: why an aspect is (not) active at a scope, as a three-valued trace of its `at`, cut at a depth
# A part is `_: st:`; `st` is the state of one eval: the names of every part, `root`, and the base helpers.
_: st:
let
  inherit (st)
    above
    all
    aspectNames
    aspects
    attrNames
    below
    byScope
    concatStringsSep
    elem
    errWith
    eval3
    filesOf
    filter
    first
    graph
    head
    isAttrs
    isFunction
    isList
    isRef
    isString
    leafOf
    length
    near
    renderId
    unknown
    unsorted
    ;
  # ── explain: why an aspect is (not) active at a scope, as a three-valued trace of its `at`, cut at a depth ──
  byId = byScope (s: s) unsorted;
  # a scope by reference: the scope itself, its path of identities, or an instance (a ref or { kind; name; }) with one
  # scope. The id string stays inside, a key: two scopes compare by sharing, never by value
  #: result.pathOf :: scope -> [ { kind; name; } ] -- the scope as a path of identities, from the root: what an answer prints and a question takes
  pathOf = s: (if s.parent == null then [ ] else pathOf s.parent) ++ [ { inherit (s) kind name; } ];
  idOfPath = p: concatStringsSep "/" (map (x: "${leafOf x.kind}:${x.name}") p); # the scope key, as mkScope
  scopeIn =
    from: t:
    let
      ss = filter (s: s.kind == t.kind && s.name == t.name) unsorted;
    in
    if isAttrs t && t ? id && byId ? ${t.id} then
      { ok = byId.${t.id}; }
    else if isList t && t != [ ] && all isRef t then
      if byId ? ${idOfPath t} then
        { ok = byId.${idOfPath t}; }
      else
        errWith from "no scope at this path" {
          code = "unknown-scope";
          got = t;
          near = map (i: pathOf byId.${i}) (near (idOfPath t) (attrNames byId));
          fix = "pass the path of a scope of result.scopes (result.pathOf s)";
        }
    else if !isRef t then
      errWith from "a scope is a scope (an arg, an element of result.scopes), its path, or an instance" {
        code = "not-a-scope";
        fix = "pass yen.<kind>.<name> or { kind; name; } (one scope), or a path [ { kind; name; } … ]";
      }
    else if length ss == 1 then
      { ok = head ss; }
    else if ss == [ ] then
      errWith from "no scope holds ${renderId t.kind} ${t.name}" {
        code = "unknown-scope";
        near = map pathOf (
          filter (s: elem s.key (near "${leafOf t.kind}:${t.name}" (map (s: s.key) unsorted))) unsorted
        );
        fix = "pass an instance that has a scope, or a path of result.scopes";
      }
    else
      errWith from "${renderId t.kind} ${t.name} has ${toString (length ss)} scopes, not one" {
        code = "scope-ambiguous";
        want = "one scope";
        scopes = map pathOf ss;
        fix = "pass one of these paths";
      };
  # a check term: a scope by reference is its id; a constant is itself
  termIn =
    t:
    let
      r = scopeIn "check" t;
    in
    if !(isAttrs t && (t ? id || isRef t) || isList t) then
      { ok = t; }
    else if r ? ok then
      { ok = r.ok.id; }
    else
      r;
  question =
    f: l:
    let
      ts = map termIn l.atom;
      bad = first (x: !(x ? ok)) ts;
    in
    if !(isAttrs l && isList (l.atom or null)) then
      errWith "check" "a check question is a literal, not a list" {
        code = "not-a-literal";
        fix = "use result.check.bad.<invariant> term, or a literal of yen.facts or yen.relations";
      }
    else if bad != null then
      bad
    else
      f (map (x: x.ok) ts);
  noScope = from: id: unknown from id (attrNames byId) { code = "unknown-scope"; };
  trace =
    d: p: s:
    let
      v = eval3 [ ] p s;
      node =
        op: x:
        {
          inherit op;
          value = v;
        }
        // x;
      kids = f: if d == 0 then "cut" else f (d - 1);
      sub = ps: { kids = kids (d': map (q: trace d' q s) ps); }; # the same scope
      at = ss: q: { kids = kids (d': map (x: { scope = pathOf x; } // trace d' q x) ss); }; # other scopes
    in
    if isFunction p then
      node "function" { }
    else if isList p then
      node "any" (sub p)
    else if p ? __all then
      node "all" (sub p.__all)
    else if p ? __not then
      node "not" (sub [ p.__not ])
    else if p ? __within then
      node "within" (at (above s) p.__within)
    else if p ? __below then
      node "below" (at (below s) p.__below)
    else if p ? __functor then
      node "function" { }
    else if p ? __kind then
      node "kind" {
        kind = {
          kind = p.__kind;
        };
      }
    else if p ? __aspect then
      node "aspect" (
        {
          aspect = {
            aspect = p.__aspect;
          };
        }
        // sub [ (aspects.${p.__aspect}.at or [ ]) ]
      )
    else if isRef p then
      node "instance" { instance = { inherit (p) kind name; }; }
    else
      node "bad-predicate" {
        fix = "a predicate is a kind, an instance, an aspect, a function, a list, or a yen.lib combinator of them";
      };
  #: result.explain :: aspect -> scope -> depth -> tree -- why an aspect is active or not at a scope, as a three-valued trace of its at; refs in, identities out
  explain =
    a: t: depth:
    let
      n = aspectIn "explain" a;
      sc = scopeIn "explain" t;
      s = sc.ok;
      v = s.__here.${n.ok};
    in
    if !(n ? ok) then
      n
    else if !(sc ? ok) then
      sc
    else
      {
        aspect.aspect = n.ok;
        scope = pathOf s;
        active = if v == null then "undefined" else v;
        at = trace depth (aspects.${n.ok}.at or [ ]) s;
        gives = map (e: { inherit (edgeOut e) sink to; }) (
          filter (e: e.origin == "aspect ${n.ok}" && e.from == s.id) graph.edges
        );
        files = filesOf n.ok;
      };
  # an aspect by reference: yen.aspects.<name>, or { aspect; } from outside the fleet
  aspectIn =
    from: a:
    let
      n = if isAttrs a then a.__aspect or a.aspect or null else null;
      x = if isString n then n else "";
    in
    if n != null && aspects ? ${n} then
      { ok = n; }
    else
      unknown from x aspectNames { code = "unknown-aspect"; }
      // {
        near = map (y: { aspect = y; }) (near x aspectNames);
      };
  # a routed element as an answer prints it: its sink and both ends by reference
  edgeOut =
    e:
    e
    // {
      sink.sink = e.sink;
      from = pathOf byId.${e.from};
      to = pathOf byId.${e.to};
    };
in
{
  inherit
    byId
    pathOf
    idOfPath
    scopeIn
    termIn
    question
    noScope
    trace
    explain
    aspectIn
    edgeOut
    ;
}
