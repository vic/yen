let
  # the host `web`, as a caller outside the fleet names it: its identity
  web = {
    kind = "host";
    name = "web";
  };
in
{
  title = "The agent surface";
  description = "What an agent reads first: `agent`, `schema`, `context`, `explain`, and trust labels by file path.";
  section = "agents";
  order = 1;

  body =
    { docs, result, ... }:
    [
      ''
        An agent that manages a fleet works through [queries](/query/queries/). Every answer is data that `builtins.toJSON` prints,
        so a tool, a script or a model reads it the same way. This page uses a fleet of three hosts with a `desktop`
        aspect for laptops and a `postgres` aspect for the database. It is the fleet of the [invariants](/query/invariants/) page.
      ''
      (docs.file "modules/fleet.nix")
      ''
        ## One call to start

        `result.agent` is the schema, the errors, the [invariant](/query/invariants/) check and the counts, JSON-safe:
      ''
      (docs.value result.agent)
      ''
        ## Why is an aspect active, or not?

        `result.explain aspect scope depth` traces `at` at one scope: the value of each node of the predicate, what the aspect gives
        there, and its files. Past the depth, `kids = "cut"`. Both are refs: `yen.aspects.postgres` and `yen.host.web` in the fleet,
        `{ aspect; }` and `{ kind; name; }` from outside it. The answer names every aspect, kind, instance and scope the same way,
        so you can pass any of them back.
      ''
      (docs.value (result.explain { aspect = "postgres"; } web 2))
      ''
        An unknown aspect or scope is an error record with `near`: the refs it was probably meant to be. A name string is no ref:
        it is an error too.

        ## Trust labels

        A label gives a trust level to the content of the files whose path contains a path part.
        Here, the files under `agent/` are written by an agent. The aspect `metrics` is declared in one of them:
      ''
      (docs.fileNoted "" "modules/labels.nix")
      (docs.file "modules/agent/metrics.nix")
      ''
        `yen.labels."<path part>" = { trust = n; }` is the form (`(1)`, `(2)`). A path part is plain text, never a pattern.
        An aspect declared in several files takes the lowest trust of them.
        When a fleet has labels, an aspect that no label covers has trust 0: unknown origin is never above a floor.
        A staged change takes its submitter's label: `stage { by = { name = "bot"; trust = 1; }; … }` (see [Stage](/agents/stage/))
        gives every aspect the change declares that trust, and `stage.floor n` lists them, even for program ops that live in no file.

        `result.labels` gives each labelled aspect. `result.floor 3` lists every routed element of an aspect below trust 3,
        with its file: what a reviewer reads first.
      ''
      (docs.value (
        map (x: {
          inherit (x) aspect trust file;
          to = x.edge.to;
        }) (result.floor 3)
      ))
      (docs.table
        [ "Query" "Answer" ]
        [
          [
            "`agent`"
            "`schema`, `errors`, `check` and counts"
          ]
          [
            "`schema`"
            "kinds, aspects (keys, files, how many scopes), invariants"
          ]
          [
            "`context id { maxEdges; maxAspects; }`"
            "one scope and its neighborhood, with `truncated`"
          ]
          [
            "`explain aspect id depth`"
            "a trace of `at` at a scope"
          ]
          [
            "`declaredIn path`"
            "the files that answer a declaration path"
          ]
          [
            "`labels`, `floor n`"
            "trust per aspect; elements below a trust"
          ]
          [
            "`impact id { hops; sinks; max; }`"
            "what a scope's elements reach, by depth"
          ]
        ]
      )
    ];

  checks =
    {
      result,
      eq,
      yes,
      no,
      ...
    }:
    {
      counts = eq (result.agent.counts) ({
        aspects = 3;
        edges = 4;
        kinds = 2;
        scopes = 4;
      });
      explain = no ((result.explain { aspect = "postgres"; } web 2).active);
      floor = {
        t1 = eq (builtins.length (result.floor 3)) (3);
        t2 = eq ((builtins.head (result.floor 3)).trust) (1);
      };
    };
}
