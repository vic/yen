{
  title = "Editor and AI batteries";
  description = "VS Code and Zed from language aspects; one pool of agent extensions (skills, MCP servers) that each agent filters.";
  section = "batteries";
  route = "batteries/editors";
  order = 9;

  body =
    { docs, ... }:
    [
      ''
        An editor's extension list grows with every language you use, and every AI agent wants the same skills and MCP
        servers in its own format. Here a language [aspect](/behavior/aspects/) gives what it needs once. Each editor and
        each agent reads from one pool. The example is one standalone home, `ana`, built with home-manager.
      ''
      (docs.fileNoted "" "modules/fleet.nix")
      ''
        The home kind has one [sink](/behavior/sinks/) for each editor and one for the agents. The batteries are the values of the sinks' `homeManager` keys.
        `(1)` builds the home. `(2)` turns the `vscode` sink into `programs.vscode`. `(3)` does the same for Zed, with
        extensions by name. At `(4)`, `agent-ext` is the pool of agent extensions. `types` says which records this agent reads:
        here, only skills.

        Each language aspect gives its part to the editors, so no editor file lists the languages:
      ''
      (docs.fileNoted "" "modules/languages.nix")
      ''
        `(1)` gives VS Code a list of extensions and its settings. `(2)` gives Zed the same language by name. At `(3)`,
        `ai.skills` reads a directory and gives one record for each subdirectory that has a `SKILL.md`. The aspect
        adds an MCP server record to the same pool. This is the skill it finds:
      ''
      (docs.file "skills/review/SKILL.md")
      ''
        The directory `notes` has no `SKILL.md`, so it is not a skill. The `github` record has the type `mcp`, so the skills agent skips it.

        ## The batteries

        | Battery | Value of | Gives |
        |---|---|---|
        | `editors.vscode { from; profile; }` | a home-manager key of a sink of `{ extensions; settings; }` | `programs.vscode` |
        | `editors.zed { from; }` | the same, extensions by name | `programs.zed-editor` |
        | `ai.extensions { from; types; build; }` | any key | `build` of the records of the given types (an element may be a list) |
        | `ai.skills dir` | an element | one `{ type = "skill"; name; path; }` per subdirectory with a SKILL.md |
      ''
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
      homes = eq (builtins.attrNames result.flake.homeConfigurations) ([ "ana" ]);
    };

  e2e =
    {
      flake,
      eq,
      yes,
      no,
      ...
    }:
    let
      c = flake.homeConfigurations.ana.config;
      vs = c.programs.vscode.profiles.default;
    in
    {
      vscode = {
        t1 = yes (c.programs.vscode.enable);
        t2 = yes (map (e: e.pname or e.name) vs.extensions != [ ]);
        t3 = eq (builtins.length vs.extensions) (2);
        t4 = yes (vs.userSettings."nix.enableLanguageServer");
      };
      zed = eq (builtins.sort builtins.lessThan c.programs.zed-editor.extensions) ([
        "go"
        "nix"
      ]);
      skills = {
        t1 = yes (c.home.file ? ".claude/skills/review");
        t2 = no ((c.home.file ? ".claude/skills/notes")); # no SKILL.md: not a skill
        t3 = no ((c.home.file ? ".claude/skills/github")); # an mcp record: the skills agent skips it
      };
    };
}
