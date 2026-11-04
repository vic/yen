self:
let
  inherit (self._prelude)
    attrNames
    b
    elem
    errWith
    head
    isAttrs
    isList
    length
    mapAttrs
    near
    nest
    words
    ;
  inherit (self._engine) eval;
  inherit (self._agents.stage) stage;
  # change programs: a change as a list of data ops, so an agent can write, check, show and replay it.
  #   { op = "set"; path; value; }          one declaration path gets a value
  #   { op = "ref"; path; kind; name; }     one declaration path gets an instance ref
  #   { op = "place"; aspect; kind; name; } the aspect is also active at that instance
  #   { op = "new"; kind; name; fields; }   a new instance (a field value { ref = { kind; name; }; } is a ref)
  program = {
    inherit
      opErrors
      validate
      toModule
      dryRun
      ;
  };
  #: lib.program.opErrors :: result -> index -> op -> [ error ] -- the errors of one program op against the fleet
  opErrors =
    r: i: o:
    opCheck r o r.schema.kinds (opFail i) (head o.path) (b.elemAt o.path 2) (
      attrNames (r.schema.kinds.${head o.path}.fields or { })
    );
  opFail = i: msg: x: [ (errWith "program[${toString i}]" msg ({ code = "program"; } // x)) ];
  # k: the kind of the path, f: its field, fs: the fields of the kind
  opCheck =
    r: o: kinds: fail: k: f: fs:
    if !isAttrs o || !(o ? op) then
      fail "not an op" { want = "{ op = …; }"; }
    else if o.op == "set" || o.op == "ref" then
      if !(isList (o.path or null)) || o.path == [ ] then
        fail "path must be a non-empty list" { }
      else if !(kinds ? ${k}) then
        fail "no kind ${k}" { near = near k (attrNames kinds); }
      else if length o.path > 2 && !elem f fs then
        fail "kind ${k} has no field ${f}" { near = near f fs; }
      else if o.op == "ref" then
        noKindIn kinds fail o
      else
        [ ]
    else if o.op == "place" then
      if r.schema.aspects ? ${o.aspect or ""} then
        [ ]
      else
        fail "no aspect ${o.aspect or "?"}" { near = near (o.aspect or "") (attrNames r.schema.aspects); }
    else if o.op == "new" then
      noKindIn kinds fail o
    else
      fail "unknown op ${toString o.op}" {
        near = near (toString o.op) (words "set ref place new");
      };
  #: lib.program.validate :: result -> [ op ] -> [ error ] -- the errors of every op of a program
  validate = r: prog: b.concatLists (b.genList (i: opErrors r i (b.elemAt prog i)) (length prog));
  noKindIn =
    kinds: fail: o:
    if kinds ? ${o.kind or ""} then [ ] else fail "no kind ${o.kind or "?"}" { };
  # the program as one yen module (a function: refs need `yen`)
  #: lib.program.toModule :: [ op ] -> module -- the program as one yen module
  toModule =
    prog:
    { yen, ... }:
    {
      imports = map (o: { yen = opModule yen o; }) prog;
    };
  refIn = yen: x: if isAttrs x && x ? ref then yen.${x.ref.kind}.${x.ref.name} else x;
  opModule =
    yen: o:
    if o.op == "set" then
      nest o.path o.value
    else if o.op == "ref" then
      nest o.path yen.${o.kind}.${o.name}
    else if o.op == "place" then
      { aspects.${o.aspect}.at = [ { inherit (o) kind name; } ]; }
    else
      { ${o.kind}.${o.name} = mapAttrs (_: refIn yen) (o.fields or { }); };
  #: lib.program.dryRun :: { base; prog; grant ? null; rejected ? [ ]; by ? null; result ? eval base; } -> stage answer // { valid; } -- validate the program, then stage it
  dryRun =
    {
      base,
      prog,
      grant ? null,
      rejected ? [ ],
      by ? null,
      result ? eval base,
    }:
    dryRunWith (validate result prog) (stage {
      inherit
        base
        grant
        rejected
        by
        ;
      baseResult = result;
      change = toModule prog;
      id = b.hashString "sha256" (b.toJSON prog); # a program is data: `rejected` matches it
    });
  # errs: the errors of the program; s: its stage
  dryRunWith =
    errs: s:
    if errs != [ ] then
      {
        ok = false;
        valid = false;
        errors = errs;
      }
    else
      removeAttrs s [ "render" ] // { valid = true; };
  # a change as data: set one declaration path (`change.set [ "host" "web-1" "port" ] 8080`)
  change = {
    #: lib.change.set :: [ name ] -> value -> module -- a module that gives one declaration path a value
    set = path: value: { yen = nest path value; };
  };
in
{
  inherit
    program
    change
    ;
}
