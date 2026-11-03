let
  toolsOf = inputs: builtins.fromJSON (builtins.readFile (inputs.yen + "/mcp/src/tools.json"));
  skillOf = inputs: builtins.readFile (inputs.yen + "/skills/yen-mcp/SKILL.md");
  # the tool names the skill mentions
  usedIn =
    skill:
    builtins.filter (n: builtins.substring 0 4 n == "yen_") (
      map (x: if builtins.isList x then builtins.head x else "") (builtins.split "(yen_[a-z_]+)" skill)
    );
  mentions =
    skill: t: builtins.match ".*`${t}`.*" (builtins.replaceStrings [ "\n" ] [ " " ] skill) != null;
in
{
  title = "MCP server";
  description = "Agents ask a fleet over stdio JSON-RPC: schema, check, context, explain, stage, programs and stored queries.";
  section = "agents";
  order = 5;

  body =
    { docs, inputs, ... }:
    [
      ''
        Yen ships an MCP server: `mcp/` at the top of the repository, a small Rust binary.
        `mcp/` is its own flake, written with Yen: `nix run github:vic/yen?dir=mcp` serves the fleet in the working
        directory, and `packages.<system>.yen-mcp` is the package. It answers agents over stdio
        (JSON-RPC 2.0, one message per line) by running yen [queries](/query/queries/) on the fleet. It serves the fleet in its directory.
      ''
      (docs.sh ''
        cd reference
        nix run github:vic/yen?dir=mcp
      '')
      ''
        ## Tools

        This table is read from the tool list the server embeds (`mcp/src/tools.json`) (${toString (builtins.length (toolsOf inputs))} tools):
      ''
      (docs.table [ "Tool" "What it answers" ] (
        map (t: [
          "`${t.name}`"
          # MDX reads a bare { as a JSX expression: escape the braces in the description text
          (builtins.replaceStrings [ "{" "}" ] [ "\\{" "\\}" ] t.description)
        ]) (toolsOf inputs)
      ))
      ''
        Each answer is `{ complete; result }`, or `{ complete = false; error }`. A timeout is never an empty answer.
        The repository ships a skill that teaches agents the order of calls, the answer shapes and the refusals:
        `skills/yen-mcp/SKILL.md`, at the top of the repository. This page checks that it names every tool,
        and no other.
        Arguments reach Nix through a file and `builtins.fromJSON`, never through string interpolation.

        ## Register it

        Any MCP client that starts a stdio server can use it. For example, in an `mcpServers` config:
      ''
      (docs.code "json" ''
        { "mcpServers": { "yen": { "command": "nix", "args": [ "run", "/path/to/fleet#yen-mcp" ] } } }
      '')
      (docs.table
        [ "Variable" "Meaning" ]
        [
          [
            "`YEN_FLEET`"
            "the fleet directory (default: the working directory)"
          ]
          [
            "`YEN_FLAKE`"
            "its flake ref (default: from the git top)"
          ]
          [
            "`YEN_TIMEOUT`"
            "seconds per nix call (default 120)"
          ]
        ]
      )
      (docs.tip "Your own fleet" ''
        Nothing to copy into your fleet. Run the mcp flake from the fleet's directory, as above. The server needs only
        the queries of the other agent pages: `schema`, `check`, `context`, `explain`, stored queries, `stage` and `program`.
        `mcp/test.sh` drives every tool.
      '')
    ];

  checks =
    {
      inputs,
      eq,
      yes,
      no,
      ...
    }:
    {
      tools = eq (builtins.length (toolsOf inputs)) 15;
      # the agent skill names every tool the server serves, and no tool it does not
      skill = {
        t1 = yes (builtins.all (t: mentions (skillOf inputs) t.name) (toolsOf inputs));
        t2 = yes (
          builtins.all (n: builtins.elem n (map (t: t.name) (toolsOf inputs))) (usedIn (skillOf inputs))
        );
      };
    };
}
