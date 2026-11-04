# The public flat lib: every name of the root `lib` output, listed once.
self: {
  inherit (self._core.static)
    is
    opt
    derive
    maybe
    listOf
    functionTo
    oneOf
    str
    int
    bool
    port
    path
    attrs
    any
    enum
    attrsOf
    secret
    jsonSafe
    kind
    aspect
    reduce
    validAt
    ;
  inherit (self)
    graphs
    rdf
    datalog
    uKanren
    batteries
    kits
    ;
  inherit (self._engine)
    eval
    asOf
    history
    mkFlake
    stage
    change
    program
    diffData
    without
    grant
    narrow
    allowed
    ;
}
