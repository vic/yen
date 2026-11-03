# One host, and its agents: each a container with the tools of one kind of work.
{ yen, ... }:
{
  yen.host.dev.agent = {
    go.packages = [
      "go"
      "gopls"
    ];
    rust.packages = [
      "cargo"
      "rustc"
      "rust-analyzer"
    ];
    web.packages = [
      "typescript"
      "pnpm"
    ];
  };

  yen.aspects.dev = {
    at = yen.host.dev;
    nixos = {
      networking.hostName = "dev";
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
