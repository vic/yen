# Ground rules { head; pos; neg; }, one set per host. Each atom is a relation called by reference, each term an instance.
{ yen, lib, ... }:
let
  D = yen.lib.datalog;
  inherit (yen.relations)
    web
    up
    serves
    drained
    primary
    ;
  all.instances = yen.kinds.host; # a tree request: every host, with its data
  rules =
    hosts:
    lib.concatMap (
      h:
      lib.optional h.web { head = web h; }
      ++ lib.optional (!h.maintenance) { head = up h; }
      ++ [
        {
          head = serves h;
          pos = [ (web h) ];
          neg = [ (drained h) ];
        }
      ]
      ++ map (d: {
        head = drained h;
        neg = [ (up d) ];
      }) h.dependsOn
    ) hosts
    # a choice: exactly one primary database, and the policy does not say which
    ++ [
      {
        head = primary yen.host.db-1;
        neg = [ (primary yen.host.db-2) ];
      }
      {
        head = primary yen.host.db-2;
        neg = [ (primary yen.host.db-1) ];
      }
    ];
  dbs = [
    yen.host.db-1
    yen.host.db-2
  ];
  names = map (h: h.name);
  # the answers for the rules `rs` of the hosts and their well-founded `model`
  answers = hosts: rs: model: {
    serves = names (lib.filter (h: model.holds (serves h)) hosts);
    undefined = model.undefined; # well-founded: the choice stays open
    # stable models: each choice
    choices = map (m: names (lib.filter (d: lib.elem (D.atom (primary d)) m) dbs)) (D.stable rs);
    whyNot = D.whyNot rs model (serves yen.host.web-2);
    proof = D.proof rs model (serves yen.host.web-1);
  };
  servingOf = hosts: answers hosts (rules hosts) (D.wfs (rules hosts));
in
{
  yen.relations = {
    web.arity = 1;
    up.arity = 1;
    serves.arity = 1;
    drained.arity = 1;
    primary.arity = 1;
  };
  yen.aspects.serving = {
    at = yen.kinds.fleet;
    cycle =
      { tree, ... }:
      {
        tree = [ all ];
        out = [ { serving = servingOf (lib.head (tree.select all)); } ];
      };
  };
}
