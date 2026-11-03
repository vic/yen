# The public flat lib: every name of the root `lib` output, listed once.
self: {
  inherit (self._core.static)
    is
    typed
    opt
    derive
    maybe
    listOf
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
    krn
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
