#: lib.batteries.vars.generators :: { machineOf; } -> reduce -- clan vars generators, shared or per machine, with dependency checks
# a reduce for clan vars generators: elements `{ name; files; share ? false; dependencies ? [ ]; }` or a list of them
# (null gives nothing, alone or in a list). A shared generator is one for every machine that gives it; any other is keyed name@machine. A dependency
# must name a generator the same machine has, or a shared one. A dependency cycle among a machine's generators is an
# error `ordered-cycle` (as battery `ordered` gives): it has no generation order. value: key -> generator // { machines; }.
#   yen.kinds.fleet.sinks.generators.reduce = clan.generators { machineOf = s: if holds yen.kinds.member s then s.parent else s; };
self:
{ machineOf }:
es:
let
  b = builtins;
  inherit (self) graphs;
  keyOf = g: if g.share or false then g.name else "${g.name}@${g.machine}";
  unique = b.foldl' (acc: x: if b.elem x acc then acc else acc ++ [ x ]) [ ];
  gs = b.concatMap (
    e:
    map (g: g // { machine = (machineOf e.from).name; }) (
      b.filter (g: g != null) (if b.isList e.value then e.value else [ e.value ])
    )
  ) es;
  byKey = b.mapAttrs (
    _: xs: b.removeAttrs (b.head xs) [ "machine" ] // { machines = unique (map (g: g.machine) xs); }
  ) (b.groupBy keyOf gs);
  # a machine's generators by name, each with its dependencies on that machine: the graph vars-plan orders
  mineOf = m: b.filter (g: b.elem m g.machines) (b.attrValues byKey);
  graphOf =
    m:
    b.listToAttrs (
      map (g: {
        inherit (g) name;
        value = b.filter (d: b.elem d (map (x: x.name) (mineOf m))) (g.dependencies or [ ]);
      }) (mineOf m)
    );
  cycleOf =
    m: t:
    if t.ok then
      [ ]
    else
      [
        {
          error = "vars: a dependency cycle among the generators of ${m}";
          code = "ordered-cycle";
          got = t.stuck;
        }
      ];
in
{
  value = byKey;
  errors =
    b.concatMap (
      g:
      map (d: { error = "vars: generator ${keyOf g} depends on ${d}, which ${g.machine} has not"; }) (
        b.filter (d: !(byKey ? ${d} || byKey ? "${d}@${g.machine}")) (g.dependencies or [ ])
      )
    ) gs
    ++ b.concatMap (m: cycleOf m (graphs.topo (graphOf m))) (unique (map (g: g.machine) gs));
}
