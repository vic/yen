# `G.of nodes next`: a graph over instances. Here: every host, and the hosts it depends on. Answers are refs.
{ yen, lib, ... }:
let
  G = yen.lib.graphs; # (1)
  all.instances = yen.kinds.host; # (2) a tree request: every host, with its data
  names = map (h: h.name);
  # the plan for the hosts and their dependency graph g
  planOf = hosts: g: {
    out = [
      {
        deploy = {
          waves = map names (G.layers g); # (3) dependencies first: each wave after the waves it depends on
          impact = lib.listToAttrs (map (h: lib.nameValuePair h.name (names (G.reachers g h))) hosts); # (4) who breaks if this host is down
          path = names (G.shortest g yen.host.lb yen.host.db); # (5)
        };
      }
    ];
    errors = [
      (map (c: "deploy: a dependency cycle: ${lib.concatStringsSep " -> " (names c)}") (
        lib.filter (c: lib.length c > 1) (G.sccs g) # (6)
      ))
    ]; # one element: the list, as before
  };
  planFor = hosts: planOf hosts (G.of hosts (h: h.dependsOn)); # (7)
in
{
  yen.aspects.deploy-plan = {
    at = yen.kinds.fleet;
    cycle = { tree, ... }: { tree = [ all ]; } // planFor (tree.select all);
  };
}
