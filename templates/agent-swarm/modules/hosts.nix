# One host: it serves ollama's OpenAI-compatible endpoint, and runs three agents on it.
{ yen, ... }:
{
  yen.host.ai.agent = {
    reviewer = {
      model = "qwen2.5-coder:7b";
      prompt = "List three risks a code review of a NixOS fleet should look for.";
      every = "daily";
    };
    writer = {
      model = "llama3.2:3b";
      prompt = "Write a one-paragraph status note for a homelab.";
    };
    planner = {
      model = "llama3.2:3b";
      prompt = "Plan the next three maintenance tasks for a small fleet.";
      every = "weekly";
    };
  };

  # the endpoint: ollama, with the models the agents use
  yen.aspects.ollama = {
    at = yen.host.ai;
    nixos = {
      services.ollama = {
        enable = true;
        loadModels = [
          "qwen2.5-coder:7b"
          "llama3.2:3b"
        ];
      };
      networking.hostName = "ai";
      nixpkgs.hostPlatform = "x86_64-linux";
      # placeholder: change fileSystems and boot for your hardware
      boot.loader.grub.device = "nodev";
      fileSystems."/" = {
        device = "/dev/disk/by-label/nixos";
        fsType = "ext4";
      };
      system.stateVersion = "25.05";
    };
  };
}
