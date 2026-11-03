{
  # build: nixos-rebuild build --flake .#ai. On the host: systemctl list-timers 'agent-*', ls /var/lib/agents
  description = "A swarm of agents on one OpenAI-compatible endpoint: each a model, a prompt and a schedule";

  outputs =
    inputs:
    inputs.yen.lib.mkFlake {
      inherit inputs;
      inherit (inputs.nixpkgs) lib;
    } (inputs.import-tree ./modules);

  inputs = {
    yen.url = "github:vic/yen";
    import-tree.url = "github:denful/import-tree";
    nixpkgs.url = "https://nixos.org/channels/nixos-25.05/nixexprs.tar.xz";
  };
}
