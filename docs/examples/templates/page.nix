let
  root = ../../../templates;
  # every directory of templates/ but the showcase template: the list cannot go stale
  dirs = builtins.readDir root;
  names = builtins.filter (n: dirs.${n} == "directory" && n != "reference") (builtins.attrNames dirs);
  has = n: f: builtins.pathExists (root + "/${n}/${f}");
  # a flake template says what it is in its flake.nix; noflake in the first comment of its default.nix
  describe =
    n:
    if has n "flake.nix" then
      (import (root + "/${n}/flake.nix")).description
    else
      builtins.substring 2 200 (
        builtins.head (builtins.split "\n" (builtins.readFile (root + "/${n}/default.nix")))
      );
  start =
    n:
    if has n "flake.nix" then
      "`nix flake init -t github:vic/yen#${n}`"
    else
      "`curl -L https://github.com/vic/yen/archive/main.tar.gz | tar xz --strip-components=2 yen-main/templates/${n}`, then in `${n}/`: `nix-build -A nixosConfigurations.laptop.config.system.build.toplevel`";
  # a template's own flake.nix, with the docs inputs; flake-parts reads self as a flake, not a path
  selfOf = all: n: {
    outPath = root + "/${n}";
    inputs = all;
    outputs = (import (root + "/${n}/flake.nix")).outputs all;
  };
  inputsOf =
    inputs: n: extra:
    inputs // extra // { self = selfOf (inputsOf inputs n extra) n; };
  # the kits templates import disko's NixOS module; a stand-in, so the docs flake needs no disko input
  disko.nixosModules.disko =
    { lib, ... }:
    {
      options.disko.devices = lib.mkOption { type = lib.types.attrs; };
    };
  hosts = t: builtins.mapAttrs (_: h: h.config) t.nixosConfigurations;
  sshd = t: builtins.mapAttrs (_: c: c.services.openssh.enable) (hosts t);
  # every template, evaluated with the docs inputs
  builtOf = inputs: {
    minimal = (inputsOf inputs "minimal" { }).self.outputs;
    noflake = import (root + "/noflake") {
      yen = inputs.yen.outPath;
      nixpkgs = inputs.nixpkgs.outPath;
      inherit (inputs) import-tree;
    };
    flake-parts =
      (inputsOf inputs "flake-parts" { inherit (inputs.terranix.inputs) flake-parts; }).self.outputs;
    multi-platform = (inputsOf inputs "multi-platform" { }).self.outputs;
    basic-fleet = (inputsOf inputs "basic-fleet" { }).self.outputs;
    neovim = (inputsOf inputs "neovim" { nixpkgs = inputs.nixpkgs-unstable; }).self.outputs;
    agent-containers = (inputsOf inputs "agent-containers" { }).self.outputs;
    k8s-services = (inputsOf inputs "k8s-services" { }).self.outputs;
    agent-swarm = (inputsOf inputs "agent-swarm" { }).self.outputs;
    kits-base = (inputsOf inputs "kits-base" { inherit disko; }).self.outputs;
    kits-homelab = (inputsOf inputs "kits-homelab" { inherit disko; }).self.outputs;
  };
  laptop = c: c.nixosConfigurations.laptop.config;
  # agent swarm: the agent timers, the models and the endpoint of host config c
  swarmFacts = c: {
    timers = builtins.mapAttrs (_: t: t.timerConfig.OnCalendar) (
      builtins.removeAttrs c.systemd.timers (
        builtins.filter (n: builtins.substring 0 6 n != "agent-") (builtins.attrNames c.systemd.timers)
      )
    );
    models = c.services.ollama.loadModels;
    endpoint = builtins.match ".*(http://127.0.0.1:11434/v1/chat/completions).*" c.systemd.services.agent-writer.script;
  };
  # agent containers: their names, the read-only login, the first tools of `go`
  containerFacts = c: {
    names = builtins.attrNames c;
    creds = c.go.bindMounts."/home/dev/.claude/.credentials.json".isReadOnly;
    # the common tools, then the agent's own; NixOS adds its base packages after them
    tools = builtins.genList (i: (builtins.elemAt c.go.config.environment.systemPackages i).pname) 6;
  };
  # the homelab's dummy WireGuard public key of host h, and whether a key is well formed (44 base64 chars ending in `=`)
  wgKey = h: builtins.readFile (root + "/kits-homelab/vars/${h}/from-exports/wg-lab-wg.pub/value");
  wellFormed = k: builtins.stringLength k == 44 && builtins.substring 43 1 k == "=";
  checksOf = eq: t: {
    minimal = eq (laptop t.minimal).networking.hostName "laptop";
    noflake = eq (laptop t.noflake).networking.hostName "laptop";
    # flake-parts changes nothing in the system yen builds
    flake-parts = eq (laptop t.flake-parts).system.build.toplevel.drvPath (laptop t.minimal)
    .system.build.toplevel.drvPath;
    flake-parts-per-system = eq t.flake-parts.formatter.x86_64-linux.name "nixfmt-tree";
    multi-nixos = eq t.multi-platform.nixosConfigurations.server.config.home-manager.users.alice.home.stateVersion "25.05";
    multi-darwin = eq t.multi-platform.darwinConfigurations.studio.config.networking.hostName "studio";
    multi-home = eq t.multi-platform.homeConfigurations."alice@work".config.home.username "alice";
    # basic fleet: each host in the domain of its environment, a deploy-rs node per host, a dev shell per environment
    basic-fleet-fqdn =
      eq (builtins.mapAttrs (_: c: c.networking.fqdnOrHostName) (hosts t.basic-fleet))
        {
          lab = "lab.dev.example.org";
          web = "web.prod.example.org";
        };
    basic-fleet-deploy = eq (builtins.mapAttrs (_: n: n.hostname) t.basic-fleet.deploy.nodes) {
      lab = "lab.dev.example.org";
      web = "web.prod.example.org";
    };
    basic-fleet-users = eq (builtins.attrNames (hosts t.basic-fleet).web.home-manager.users) [
      "alice"
    ];
    basic-fleet-mac = eq t.basic-fleet.darwinConfigurations.studio.config.networking.hostName "studio";
    basic-fleet-home = eq t.basic-fleet.homeConfigurations."alice@laptop".config.home.username "alice";
    # agent swarm: one service and timer per agent, on the host's ollama endpoint
    swarm = eq (swarmFacts (hosts t.agent-swarm).ai) {
      timers = {
        agent-planner = "weekly";
        agent-reviewer = "daily";
        agent-writer = "hourly";
      };
      models = [
        "qwen2.5-coder:7b"
        "llama3.2:3b"
      ];
      endpoint = [ "http://127.0.0.1:11434/v1/chat/completions" ];
    };
    # k8s services: two charts, two image apps, a ServiceMonitor for the app with metrics, and the apply list
    k8s = eq (builtins.attrNames t.k8s-services.k8sManifests.lab) [
      "api-deployment"
      "api-ingress"
      "api-monitor"
      "api-service"
      "conduit-deployment"
      "conduit-ingress"
      "conduit-service"
      "gitea-chart"
      "monitoring-chart"
    ];
    k8s-apply = eq (builtins.isString t.k8s-services.packages.x86_64-linux.lab.drvPath) true;
    # agent containers: one per agent, each with its tools and the shared login, read-only
    agents = eq (containerFacts (hosts t.agent-containers).dev.containers) {
      names = [
        "go"
        "rust"
        "web"
      ];
      creds = true;
      tools = [
        "claude-code"
        "git"
        "jujutsu"
        "nodejs"
        "go"
        "gopls"
      ];
    };
    # neovim: a terminal editor and a neovide one per variant, each a derivation
    neovim-variants = eq (builtins.attrNames t.neovim.packages.x86_64-linux) [
      "go"
      "go-gui"
      "web"
      "web-gui"
      "writer"
      "writer-gui"
    ];
    neovim-builds = eq (builtins.all (p: builtins.isString p.drvPath) (
      builtins.attrValues t.neovim.packages.x86_64-linux
    )) true;
    basic-fleet-shells = eq (builtins.attrNames t.basic-fleet.devShells.x86_64-linux) [
      "dev"
      "prod"
    ];
    # bundle base: every machine gets its disk layout and an ssh server
    kits-base = eq (sshd t.kits-base) {
      db = true;
      web = true;
    };
    kits-base-disks = eq (builtins.attrNames (hosts t.kits-base).db.disko.devices) [ "disk" ];
    # bundle homelab: base everywhere, a wireguard network, the server monitors, the nodes are backed up
    kits-homelab = eq (sshd t.kits-homelab) {
      lb = true;
      nas = true;
      web = true;
    };
    kits-homelab-wg =
      eq (builtins.attrNames (hosts t.kits-homelab).web.networking.wireguard.interfaces)
        [
          "lab-wg"
        ];
    kits-homelab-monitor = eq (hosts t.kits-homelab).nas.services.prometheus.enable true;
    kits-homelab-backup = eq (builtins.attrNames (hosts t.kits-homelab).web.services.borgbackup.jobs) [
      "lab-borg"
    ];
  };
in
{
  title = "Templates";
  description = "Start a new project from a template.";
  section = "start";
  order = 6;

  body =
    { docs, ... }:
    [
      ''
        These are small projects for you to copy and grow. The examples in these docs show one idea each;
        a template is a whole project. Each one here is evaluated in our CI.
      ''
      (docs.table [ "Template" "What it is" "Start" ] (
        map (n: [
          "`${n}`"
          (describe n)
          (start n)
        ]) names
      ))
      ''
        Not sure which one? Take `minimal`. [Getting started](/start/getting-started/) is the same host with a step-by-step page.
        `noflake` needs no flake: [Project layout](/start/project-layout/) explains both entry points.
        `reference` is the [showcase template](https://github.com/vic/yen/tree/main/reference). Read it, but do not start from it: its `yen` input is this repository.
        New to the words in the table? Read the [overview](/start/overview/) and the [glossary](/reference/glossary/).
      ''
    ];

  checks =
    { eq, yes, ... }:
    {
      # the flake output is a set, not a function waiting for its args
      is-set = yes (builtins.isAttrs (import ../../templates.nix));
      # the docs flake lists every template under its own name, and no example has the same name
      listed = eq (builtins.filter (
        n: !(import ../../templates.nix) ? ${n} && has n "flake.nix"
      ) names) [ ];
      names-free = eq (builtins.filter (n: builtins.pathExists (../. + "/${n}")) names) [ ];
      # a new template directory needs its e2e: builtOf has one key per template (keys only, nothing evaluates)
      e2e-every-template = eq (builtins.attrNames (builtOf { })) names;
      # the homelab's dummy WireGuard public keys are well formed: 44 characters of base64 ending in `=`
      homelab-wg-keys =
        eq
          (builtins.map (h: wellFormed (wgKey h)) [
            "lb"
            "nas"
            "web"
          ])
          [
            true
            true
            true
          ];
    };

  e2e = { inputs, eq, ... }: checksOf eq (builtOf inputs);
}
