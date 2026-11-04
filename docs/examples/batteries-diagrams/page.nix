let
  has = s: t: builtins.replaceStrings [ s ] [ "" ] t != t; # literal substring
in
{
  title = "Diagram and docs batteries";
  description = "mermaid views of scopes, kinds, gates and routes; tables, links that follow edits, doc lines checked against live names.";
  section = "batteries";
  route = "batteries/diagrams";
  order = 6;

  body =
    {
      docs,
      result,
      variant,
      ...
    }:
    [
      ''
        Docs drift when they are written by hand. [Batteries](/batteries/) make diagrams, tables and links from the fleet itself:
        a renamed [kind](/model/kinds-fields/), a new host or a moved line shows up in the next `nix run .#write-files`, or fails the eval.
        This example is a small fleet to draw: environments hold hosts, and a host may refer to its database host.
      ''
      (docs.file "modules/fleet.nix")
      ''
        The diagrams are values of the fleet. The aspect `diagrams` asks yen for the whole fleet with a tree request
        and draws each view from it.
      ''
      (docs.fileNoted "" "modules/diagrams.nix")
      ''
        A view is plain data, `{ nodes; edges; }`, and `flowchart` renders it as text. At `(1)`, `group` puts each host in a
        subgraph named by its environment. `(2)` draws the kinds, `(3)` the aspects that other aspects name in `at`, and `(4)` who
        gives what to whom. At `(5)`, `routing` counts at kind level and `sinks` shows the [sinks](/behavior/sinks/) that give to sinks and to
        flake outputs. At `(6)`, `tree = [ whole ]` is the tree request.

        ## Scopes, grouped by environment

        A [scope](/model/scopes/) is drawn under its parent. The environments are subgraphs:
      ''
      (docs.mermaid result.flake.diagrams.scopes)
      ''
        ## Kinds

        A dotted edge is a field that refers to a kind.
      ''
      (docs.mermaid result.flake.diagrams.kinds)
      ''
        ## Gates

        `monitored` reads `server`, and `legacy` under a `not`. A dashed edge is a read under `not`.
      ''
      (docs.mermaid result.flake.diagrams.gates)
      ''
        ## Routes

        Who gives what to whom:
      ''
      (docs.mermaid result.flake.diagrams.routes)
      ''
        ## Routing by kind, and sinks
      ''
      (docs.mermaid result.flake.diagrams.routing)
      (docs.mermaid result.flake.diagrams.sinks)
      ''
        ## Tables, links and a vocabulary

        Tables, links that follow edits, and doc lines checked against the live names come from the same fleet:
      ''
      (docs.fileNoted "" "modules/docs.nix")
      ''
        `(1)` makes the table of kinds, with their spawns, sinks and counts:
      ''
      result.flake.kinds
      ''
        Any table works the same way: the hosts and their environment.
      ''
      result.flake.hosts
      ''
        `(2)` and `(3)` make a link to the first line of `fleet.nix` that holds the needle `db = maybe`. The [reduce](/behavior/sinks/) of the sink
        gives the links by `name`. A flake template for each directory that has a `flake.nix`:
      ''
      (docs.value result.flake.templates)
      ''

        The link follows the line: `${result.flake.links.db-field}`. At `(4)`, a kind with no doc line is an error:
      ''
      (docs.value (map (e: { inherit (e) error code; }) (variant "variants/new-kind.nix").errors))
      ''
        ## The batteries

        | Battery | Gives |
        |---|---|
        | `mermaid.flowchart { direction; shapes; } view` | the text of a flowchart; a node that others name as `group` is a subgraph |
        | `mermaid.scopes { keep; label; group; edge; } graph` | a view of the scopes, each under its parent |
        | `mermaid.routes graph`, `mermaid.routing graph` | who gives what to whom; at kind level with counts |
        | `mermaid.kinds kinds`, `mermaid.sinks lib` | [spawns](/model/scopes/) and ref fields; sinks that give to sinks and to flake outputs |
        | `mermaid.gates aspects` | the [aspects](/behavior/aspects/) other aspects name in `at`, and what each reads (dashed under `not`) |
        | `docs.table head rows`, `docs.kinds kinds graph` | markdown tables |
        | `docs.links { root; base; }` | a reduce: links to the first line that contains a needle; a gone needle is an error |
        | `docs.vocabulary { what; names; lines; }` | errors: a live name with no doc line, a doc line with no live name |
        | `docs.templates { root; description; }` | flake templates from the directories that have a flake.nix (these docs use it) |
        | `docs.starlight-page`, `docs.starlight-sidebar`, `docs.starlight-tests`, `docs.starlight-writers` | a Starlight docs site in a fleet; see [Starlight docs battery](/batteries/starlight/) |
      ''
    ];

  checks =
    {
      result,
      variant,
      eq,
      yes,
      no,
      ...
    }:
    {
      scopes = {
        t1 = yes (has "subgraph" result.flake.diagrams.scopes);
        t2 = yes (has "[\"prod\"]" result.flake.diagrams.scopes);
        t3 = no ((has "fleet" result.flake.diagrams.scopes));
      };
      kinds = yes (has "-.->|\"db\"|" result.flake.diagrams.kinds);
      gates = yes (has "-.->|\"not\"|" result.flake.diagrams.gates);
      routes = yes (has "-->|\"inventory\"|" result.flake.diagrams.routes);
      inventory = eq (result.flake.inventory) ({
        dev = [ "lab" ];
        prod = [
          "pg"
          "web"
        ];
      });
      table = yes (has "| `host` | `db`, `environment` |  | `nixos` | 3 |" result.flake.kinds);
      routing = {
        t1 = yes (has "|\"1\"|" result.flake.diagrams.routing);
        t2 = yes (has "(\"inventory\")" result.flake.diagrams.routing);
      };
      sinks = yes (has "[(\"flake outputs\")]" result.flake.diagrams.sinks);
      hosts-table = yes (has "| lab | dev |" result.flake.hosts);
      templates = eq (result.flake.templates) ({ hello = "hello: the smallest flake"; });
      links = eq (result.flake.links.db-field) ("[`db`](fleet.nix#L23)");
      vocabulary = eq (map (e: e.code) (variant "variants/new-kind.nix").errors) ([ "doc-missing" ]);
    };
}
