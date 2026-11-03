# µKanren with finite domains: give each app a port in 8080..8083, all different, prometheus before grafana.
{ yen, lib, ... }:
let
  inherit (yen.lib.krn)
    run
    runAll
    freshNamed
    infd
    distinctfd
    ltfd
    eq
    label
    runFuel
    ;
  ports =
    apps: q:
    freshNamed apps (vs: [
      (infd (lib.attrValues vs) 8080 8083)
      (distinctfd (lib.attrValues vs))
      (ltfd vs.prometheus vs.grafana)
      (eq q vs)
      (label (lib.attrValues vs))
    ]);
  lb.scopesOf = yen.host.lb; # a tree request: lb, with its data
  appsOf = tree: (lib.head (lib.head (tree.select lb))).apps;
in
{
  yen.aspects.ports = {
    at = yen.kinds.fleet;
    cycle =
      { tree, ... }:
      {
        tree = [ lb ];
        out = [
          {
            ports = {
              first = run 1 (ports (appsOf tree)); # one answer
              count = lib.length (runAll (ports (appsOf tree))); # every answer
              # the same relation, run backward: which app can take 8080?
              on8080 = lib.unique (
                lib.concatMap (a: lib.attrNames (lib.filterAttrs (_: p: p == 8080) a)) (
                  runAll (ports (appsOf tree))
                )
              );
              # a bounded search: `complete = false` means "stopped", never "no answer"
              bounded = removeAttrs (runFuel 1 5 (ports (appsOf tree))) [ "answers" ];
            };
          }
        ];
        errors = [ (lib.optional (run 1 (ports (appsOf tree)) == [ ]) "ports: no assignment for lb") ];
      };
  };
}
