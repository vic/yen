# A host runs agents. An agent is a kind of the host (it exists only under its host) and owns the aspect that makes
# its NixOS container: by default the aspect runs at every agent. Its container gets its own tools and its own
# ~/.claude (memories and settings stay apart), and one read-only bind of the host's credentials file, so every
# agent uses the same login.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  # the host file with the Claude Code login, made once on the host with `claude login`
  credentials = "/var/lib/claude/.credentials.json";
  # in every container: the agent, version control, and the MCP servers' runtime
  common = [
    "claude-code"
    "git"
    "jujutsu"
    "nodejs"
  ];
in
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.fleet.main = { };
  yen.flake = { out, ... }: out;

  yen.kinds.host = {
    sinks.nixos.out =
      { host, nixos, ... }:
      {
        nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem { modules = nixos; };
      };
    kinds.agent = {
      fields.packages = yen.lib.listOf yen.lib.str; # nixpkgs attribute names: the agent's own tools
      aspects.container.nixos =
        { agent, ... }:
        {
          containers.${agent.name} = {
            autoStart = true;
            bindMounts."/home/dev/.claude/.credentials.json" = {
              hostPath = credentials;
              isReadOnly = true;
            };
            config =
              { pkgs, ... }:
              {
                nixpkgs.config.allowUnfreePredicate = p: lib.getName p == "claude-code";
                environment.systemPackages = map (n: pkgs.${n}) (common ++ agent.packages);
                users.users.dev = {
                  isNormalUser = true;
                  home = "/home/dev"; # its ~/.claude is the container's own
                };
                system.stateVersion = "25.05";
              };
          };
        };
    };
  };
}
