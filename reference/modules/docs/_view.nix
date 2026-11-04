# The view of the whole fleet that README.md shows: live tables and diagrams computed from the fleet's own queries.
# `yen` is the whole fleet, with its data, that the README's tree request selects. Every diagram is data.
{ lib, inputs }:
yen:
let
  g = yen.lib.graph;
  sorted = xs: lib.sort (a: b: a < b) (lib.unique xs);
  kinds = ''
    ## This fleet, live
    Generated from the fleet's queries: ${toString (lib.length g.scopes)} scopes, ${toString (lib.length (lib.attrNames yen.kinds))} kinds, ${toString (lib.length (lib.attrNames yen.aspects))} aspects, ${toString (lib.length g.edges)} routed elements.
    ${yen.lib.batteries.docs.kinds yen.kinds g}
    A kind with 0 scopes is data: nothing spawns it.
  '';

  # ── every view goes through the mermaid battery: nodes { id; label; kind; group }, edges { from; to; label; live } ──
  mermaid =
    view:
    "```mermaid\n"
    + yen.lib.batteries.mermaid.flowchart {
      shapes = with yen.lib.batteries.mermaid.shapes; {
        mac = round;
        guest = subroutine;
        home = parallelogram;
        user = circle;
        member = hexagon;
        assembly = hexagon;
        sink = round;
        output = cylinder;
      };
    } view
    + "\n```";
  # the first 6 of a sorted list, and how many more
  shortIn =
    s:
    lib.concatStringsSep ", " (lib.take 6 s)
    + lib.optionalString (lib.length s > 6) ", +${toString (lib.length s - 6)}";
  short = xs: shortIn (sorted xs);
  # a generator dependency d of generator v: its own name, or the per-machine one of its first machine
  depOf =
    generators: v: d:
    if generators ? ${d} then d else "${d}@${lib.head v.machines}";
  machineRow = s: as: "| `${s.name}` | ${s.kind} | ${toString (lib.length as)} | ${short as} |";
  sinkRow =
    k: es:
    "| `${k}` | ${short (map (e: kindOf.${e.from}) es)} | ${
      short (map (e: kindOf.${e.to}) es)
    } | ${toString (lib.length es)} |";
  kindOf = lib.listToAttrs (map (s: lib.nameValuePair s.id s.kind) g.scopes);
  nameOf = lib.listToAttrs (map (s: lib.nameValuePair s.id s.name) g.scopes);
  parentOf = id: lib.concatStringsSep "/" (lib.init (lib.splitString "/" id));

  # fleet map: machines grouped by environment; every scope under its parent
  envOf =
    s:
    lib.findFirst (e: lib.hasPrefix "${e.id}/" s.id) null (
      lib.filter (e: yen.lib.holds yen.kinds.environment e) g.scopes
    );
  fleetMap = {
    nodes = map (s: {
      inherit (s) id kind;
      label = if yen.lib.holds yen.kinds.environment s then "environment ${s.name}" else s.name;
      group =
        if
          !(yen.lib.holds yen.kinds.environment s)
          && envOf s != null
          && kindOf.${parentOf s.id} or null == "environment"
        then
          (envOf s).id
        else
          null;
    }) g.scopes;
    edges =
      map
        (s: {
          from = parentOf s.id;
          to = s.id;
        })
        (
          lib.filter (s: lib.hasInfix "/" s.id && kindOf.${parentOf s.id} or null != "environment") g.scopes
        );
  };

  # sink forwarding: a sink key that gives to another sink (dashed); `out` reaches flake outputs with live receivers
  forwards = yen.lib.batteries.mermaid.sinks yen.lib;

  # pools: an element routed from one kind up to another, one edge per (sink, from kind, to kind)
  routed = lib.filter (e: kindOf.${e.from} != kindOf.${e.to}) g.edges;
  pools = {
    nodes = map (k: {
      id = "kind:${k}";
      label = k;
      kind = k;
    }) (sorted (map (e: kindOf.${e.from}) routed ++ map (e: kindOf.${e.to}) routed));
    edges =
      map
        (x: {
          from = "kind:${x.f}";
          to = "kind:${x.t}";
          label = lib.concatStringsSep ", " (sorted x.ss);
        })
        (
          lib.mapAttrsToList
            (_: es: {
              inherit (lib.head es) f t;
              ss = map (e: e.s) es;
            })
            (
              lib.groupBy (x: "${x.f}>${x.t}") (
                map (e: {
                  f = kindOf.${e.from};
                  t = kindOf.${e.to};
                  s = e.sink;
                }) routed
              )
            )
        );
  };

  # assemblies: each assembly (its kit) to the machines of each role
  members = lib.filter (s: yen.lib.holds yen.kinds.member s) g.scopes;
  # graph scopes carry no fields: a member scope is named `<assembly>.<role>` by kits.members
  memberRoles = lib.concatMap (
    a:
    lib.concatMap (
      r:
      map (s: {
        inherit a r s;
      }) (lib.filter (s: s.name == "${a.name}.${r}") members)
    ) (lib.attrNames a.roles)
  ) yen.helpers.assemblies;
  assemblyView = {
    nodes =
      map (a: {
        id = "asm:${a.name}";
        label = "${a.name} (${a.kit.name})";
        kind = "assembly";
      }) (lib.filter (a: lib.any (x: x.a.name == a.name) memberRoles) yen.helpers.assemblies)
      ++ map (m: {
        id = m;
        label = nameOf.${m};
        kind = kindOf.${m};
      }) (sorted (map (s: parentOf s.id) members));
    edges = map (x: {
      from = "asm:${x.a.name}";
      to = parentOf x.s.id;
      label = x.r;
    }) memberRoles;
  };

  # vars: generator dependencies; a shared generator is one node for all its machines
  vars = generators: {
    nodes = lib.mapAttrsToList (k: v: {
      id = "gen:${k}";
      label = "${k} · ${short v.machines}";
      kind = if v.share or false then "member" else "gen";
    }) generators;
    edges = lib.concatLists (
      lib.mapAttrsToList (
        k: v:
        lib.concatMap (
          d:
          lib.optional (generators ? ${depOf generators v d}) {
            from = "gen:${depOf generators v d}";
            to = "gen:${k}";
          }
        ) (v.dependencies or [ ])
      ) generators
    );
  };

  # deploy order: a host deploys after what it depends on
  hosts = lib.filterAttrs (_: h: h ? addr) yen.host;
  deploy = {
    nodes =
      lib.mapAttrsToList
        (n: _: {
          id = "host:${n}";
          label = n;
          kind = "host";
        })
        (
          lib.filterAttrs (
            n: h: h.dependsOn != [ ] || lib.any (o: lib.any (d: d.name == n) o.dependsOn) (lib.attrValues hosts)
          ) hosts
        );
    edges = lib.concatLists (
      lib.mapAttrsToList (
        n: h:
        map (d: {
          from = "host:${d.name}";
          to = "host:${n}";
          label = "before";
        }) h.dependsOn
      ) hosts
    );
  };

  # kind tree: solid = `spawns` (parent kind to child kind), dotted = a field that is a ref to another kind
  kindTree = yen.lib.batteries.mermaid.kinds yen.kinds;
  # pools as a sequence: who sends what to whom
  sequence = lib.concatStringsSep "\n" (
    [
      "```mermaid"
      "sequenceDiagram"
    ]
    ++ map (k: "  participant ${k}") (sorted (map (e: e.label) pools.nodes))
    ++ map (
      e: "  ${lib.removePrefix "kind:" e.from}->>${lib.removePrefix "kind:" e.to}: ${e.label}"
    ) pools.edges
    ++ [ "```" ]
  );

  # summary tables
  machineScopes = lib.filter (yen.lib.holds [
    yen.kinds.host
    yen.kinds.mac
    yen.kinds.guest
  ]) g.scopes;
  aspectsAt =
    s:
    sorted (
      map (e: lib.removePrefix "aspect " e.origin) (
        lib.filter (e: e.from == s.id && lib.hasPrefix "aspect " e.origin) g.edges
      )
    ); # aspects that gave elements here (projected hasAspect)
  under = p: k: lib.filter (s: yen.lib.holds k s && lib.hasPrefix "${p.id}/" s.id) g.scopes;
  summary = ''
    ### Summary
    | Environment | Machines | Users | Clusters |
    |---|---|---|---|
    ${lib.concatMapStringsSep "\n" (
      e:
      "| `${e.name}` | ${
        short (
          map (s: s.name) (
            lib.concatMap (under e) [
              yen.kinds.host
              yen.kinds.mac
              yen.kinds.guest
            ]
          )
        )
      } | ${toString (lib.length (sorted (map (s: s.name) (under e yen.kinds.user))))} | ${
        short (map (s: s.name) (under e yen.kinds.cluster))
      } |"
    ) (lib.filter (s: yen.lib.holds yen.kinds.environment s) g.scopes)}

    | Machine | Kind | Aspects giving elements | Some aspects |
    |---|---|---|---|
    ${lib.concatMapStringsSep "\n" (s: machineRow s (aspectsAt s)) machineScopes}

    | Sink | Given at | Received at | Elements |
    |---|---|---|---|
    ${lib.concatMapStringsSep "\n" (k: sinkRow k (lib.filter (e: e.sink == k) g.edges)) (
      sorted (map (e: e.sink) g.edges)
    )}
  '';

  diagrams = generators: ''
    ### Fleet map
    Every scope, under its parent. Machines sit in their environment. `[host]` `(mac)` `[[guest]]` `[/home/]` `((user))` `{{member}}`.

    ${mermaid fleetMap}

    **Kind tree**: solid edges are `spawns`; dotted edges are fields that refer to another kind.

    ${mermaid kindTree}

    <details><summary>Sinks, pools, assemblies, vars, deploy order (diagrams)</summary>

    **Sink forwarding**: a dashed edge is a sink key that feeds another sink (label: the kind). A solid edge is `out`, labelled with the receivers that build an output.

    ${mermaid forwards}

    **Pools**: elements routed up from one kind to another, labelled with the sinks.

    ${mermaid pools}

    **Pool sequence**: the same pools as messages.

    ${sequence}

    **assemblies**: each assembly (its kit) to the machines of each role.

    ${mermaid assemblyView}

    **vars generators**: an edge is a dependency. A hexagon is shared by every machine that uses it.

    ${mermaid (vars generators)}

    **Deploy order** (`dependsOn`).

    ${mermaid deploy}

    </details>
  '';
  # ── the agent surface and every capability, generated: nothing is listed by hand, so nothing goes missing ──
  sv = import ../../../default.nix; # the engine's own lib, for the index of library functions
  fnList = xs: lib.concatMapStringsSep ", " (n: "`${n}`") (sorted xs);
  hostsWith = f: lib.attrNames (lib.filterAttrs (_: h: h ? addr && (h.${f} or false)) yen.host);
  groupKey = h: "${h.channel.name}/${h.system.name}";
  sharing = lib.filterAttrs (_: h: h ? addr && (h.sharedPkgs or false)) yen.host;
  groups = lib.groupBy (n: groupKey sharing.${n}) (sorted (lib.attrNames sharing));
  sharedView = {
    nodes = lib.concatLists (
      lib.mapAttrsToList (
        g: ns:
        [
          {
            id = "g:${g}";
            label = "pkgs ${g}";
            kind = "output";
          }
        ]
        ++ map (n: {
          id = "h:${n}";
          label = n;
          kind = "host";
        }) ns
      ) groups
    );
    edges = lib.concatLists (
      lib.mapAttrsToList (
        g: ns:
        lib.imap0 (i: n: {
          from = "g:${g}";
          to = "h:${n}";
          label = if i == 0 then "leader" else "reuses";
          live = i == 0;
        }) ns
      ) groups
    );
  };
  agentAspects = lib.attrNames (lib.filterAttrs (_: l: l.prefix == "agent/") yen.lib.labels);
  labelView = {
    nodes =
      map (p: {
        id = "p:${p}";
        label = "${p} trust ${toString yen.labelTable.${p}.trust}";
        kind = "output";
      }) (lib.attrNames yen.labelTable)
      ++ map (a: {
        id = "a:${a}";
        label = a;
        kind = "aspect";
        group = null;
      }) agentAspects;
    edges = map (a: {
      from = "p:agent/";
      to = "a:${a}";
      label = "${toString (lib.length (lib.filter (x: x.aspect == a) (yen.lib.floor 3)))} elements";
    }) agentAspects;
  };
  invView = {
    nodes =
      map (n: {
        id = "i:${n}";
        label = n;
        kind = "aspect";
      }) (lib.attrNames yen.invariants)
      ++
        map
          (f: {
            id = "f:${f}";
            label = f;
            kind = "output";
          })
          (
            lib.unique (
              lib.concatMap (
                n:
                map baseNameOf (
                  yen.lib.declaredIn [
                    "invariants"
                    n
                  ]
                )
              ) (lib.attrNames yen.invariants)
            )
          ); # base names: the same in the working tree and the store
    edges = lib.concatMap (
      n:
      map
        (f: {
          from = "f:${baseNameOf f}";
          to = "i:${n}";
        })
        (
          yen.lib.declaredIn [
            "invariants"
            n
          ]
        )
    ) (lib.attrNames yen.invariants);
  };
  mcpTools = sorted (
    map (t: t.name) (builtins.fromJSON (builtins.readFile (inputs.yen + "/mcp/src/tools.json")))
  );
  mcpView = {
    nodes = [
      {
        id = "srv";
        label = "yen-mcp (nix run github:vic/yen?dir=mcp)";
        kind = "output";
      }
    ]
    ++ map (t: {
      id = "t:${t}";
      label = t;
      kind = "sink";
    }) mcpTools;
    edges = map (t: {
      from = "srv";
      to = "t:${t}";
    }) mcpTools;
  };
  paramsOf = n: lib.attrNames yen.queries.${n}.params;
  # the optional parameters of query n: those with a default
  optsOf = n: lib.filter (p: yen.queries.${n}.params.${p} ? default) (paramsOf n);
  queryRow =
    n:
    "| `${n}` | ${fnList (lib.subtractLists (optsOf n) (paramsOf n))} | ${fnList (optsOf n)} | ${
      lib.concatStringsSep ", " (
        map baseNameOf (
          yen.lib.declaredIn [
            "queries"
            n
          ]
        )
      )
    } |";
  capabilities = ''
    ## Capability index (generated)

    Every list below is computed from the engine and this fleet when the README is written.

    **Queries on an eval result** (`result = yen.lib.eval module`): ${
      fnList (
        yen.lib.schema.queries
        ++ [
          "context"
          "explain"
          "impact"
          "labels"
          "floor"
          "data"
          "queries"
          "ask"
          "root"
        ]
      )
    }.

    **Engine library** (`yen.lib`): ${
      fnList (
        lib.filter (
          n:
          !lib.elem n [
            "graphs"
            "datalog"
            "uKanren"
            "rdf"
            "reduce"
            "program"
            "grants"
            "change"
          ]
        ) (lib.attrNames sv.lib)
      )
    }.
    Reduce strategies: ${fnList (lib.attrNames sv.lib.reduce)}. Change programs (`yen.lib.program`): ${fnList (lib.attrNames sv.lib.program)}. Grants: ${
      fnList [
        "grant"
        "narrow"
        "allowed"
      ]
    }.

    | Library | Functions |
    |---|---|
    | `yen.lib.graphs` | ${fnList (lib.attrNames sv.lib.graphs)} |
    | `yen.lib.datalog` | ${fnList (lib.attrNames sv.lib.datalog)} |
    | `yen.lib.uKanren` | ${fnList (lib.attrNames sv.lib.uKanren)} |
    | `yen.lib.rdf` | ${fnList (lib.attrNames sv.lib.rdf)} |

    **Stored queries** (`result.ask name args`):

    | Query | Required | Optional | File |
    |---|---|---|---|
    ${lib.concatMapStringsSep "\n" queryRow (sorted (lib.attrNames yen.queries))}

    **Invariants** (`result.check`): ${fnList (lib.attrNames yen.invariants)}.

    ${mermaid invView}

    **MCP tools** (${toString (lib.length mcpTools)}): ${fnList mcpTools}.

    ${mermaid mcpView}

    **Labels** (`yen.labels`, by file path): ${
      lib.concatStringsSep ", " (
        lib.mapAttrsToList (p: l: "`${p}` trust ${toString l.trust}") yen.labelTable
      )
    }. Aspects declared under `agent/` and the elements they give (`result.floor 3`):

    ${mermaid labelView}

    **Performance levers.** Shared pkgs (`sharedPkgs`): ${fnList (lib.attrNames sharing)}. Trimmed module lists (`trimmedModules`): ${fnList (hostsWith "trimmedModules")}.

    ${mermaid sharedView}

    **Research and pattern maps** (in `vic/` of the yen repository): ${
      fnList [
        "den-patterns.md"
        "den-census.md"
        "sini-patterns.md"
        "hoag-ci-patterns.txt"
        "clan-patterns.txt"
        "gen-query-research.txt"
        "ai-infra-research.md"
        "quipu-lessons.md"
        "evalmodules-research.md"
        "modlist-research.md"
        "design.md"
      ]
    }.
  '';
  jobs = ci: ''
    ### CI jobs (`ci.json`)
    | Job | System | Builds |
    |---|---|---|
    ${lib.concatMapStringsSep "\n" (j: "| `${j.name}` | `${j.system}` | `${j.attr}` |") (
      lib.attrValues ci
    )}
  '';
in
{
  inherit
    kinds
    summary
    diagrams
    capabilities
    jobs
    ;
}
