# Keys the engine reads, and the facts it extracts with their arity. `words` splits a space-separated string.
self:
let
  inherit (self._core.helpers) words;
in
{
  # keys the engine reads; the other keys of a sink, an aspect, a cycle output or a scope are data
  sinkMeta = words "at reduce of __sink";
  scopeKeys = words "kind name key parent path id up rup"; # the scope record sets these over the instance fields
  aspectMeta = words "at cycle order __aspect";
  outMeta = words "tree order";
  scopeMeta = words "kind name key parent path id up rup __here";
  requestKinds = words "nearest parent children scopesOf holds instances graph";
  # the facts yen extracts, with their arity: no rule derives them
  edbArity = {
    scope = 1;
    instance = 3;
    parent = 2;
    kind = 2;
    has = 2;
    edge = 3;
    error = 2;
    ref = 4;
    val = 3;
  };
  # the only keys `yen` and a kind declare; any other key is an error, never ignored
  yenKeys = words "kinds aspects helpers queries invariants relations labels flake sinks"; # and the kind names
  kindKeys = words "fields spawns sinks kinds";
}
