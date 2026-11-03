#: lib.batteries.mesh :: { from; build; } -> key value -- every element of sink from except this scope own, made into content by build
# every element of `from` except the ones given by this scope or under it, then `build` makes content of them.
# `from` must reduce with `yen.lib.reduce.elements`: an element knows its giver.
#   nixos = mesh { from = yen.kinds.fleet.sinks.ssh-keys; build = keys: { programs.ssh.knownHosts = …; }; };
_:
let
  b = builtins;
  hasPrefix = p: s: b.substring 0 (b.stringLength p) s == p;
  # the scope itself, or a scope under it
  own = scope: e: e.from.id == scope.id || hasPrefix "${scope.id}/" e.from.id;
in
{ from, build }:
{ scope, sinks, ... }:
build (map (e: e.value) (b.filter (e: !own scope e) sinks.${from.__sink}))
