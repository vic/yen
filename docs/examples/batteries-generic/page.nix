{
  title = "Generic batteries";
  description = "mesh, claim, ordered, eval-modules, configurations, imports: values for keys you write. And how to write your own.";
  section = "batteries";
  route = "batteries/generic";
  order = 1;

  body =
    {
      docs,
      result,
      variant,
      ...
    }:
    [
      ''
        The other pages of these docs write every rule by hand, so you can see how Yen works. Some rules come back in
        every fleet: each host reads the other hosts' keys, each address has one owner, sections of a file come
        in an order. `yen.lib.batteries` has them ready.

        A [battery](/batteries/) never adds a word to your fleet. **You write every key** with your own names, and the battery is the
        value. It reads only the fixed args `scope` and `sinks`, and it takes the [sinks](/behavior/sinks/) it reads as refs.
        The example's words are a fleet of hosts, where each host has an ssh key and an address, and the batteries know none of these names.
      ''
      (docs.file "modules/fleet.nix")
      ''
        ## What the other hosts give

        Each host gives its key to the fleet. The fleet reduces with `elements`, so each key keeps the scope that gave
        it, and then each host reads the others' keys. It's the same rule as known_hosts, WireGuard peers,
        Syncthing devices or remote builders, written by hand in [Facts from other hosts](/nixos/cross-host/).
      ''
      (docs.fileNoted "" "modules/known-hosts.nix")
      ''
        `(1)` is the fleet's sink, and `(2)` is each host's sink, whose `reduce` is `one`, so a host has exactly one value.
        At `(3)`, `mesh` gives the value of the `known` key: the records of sink `from`, except the ones that
        this [scope](/model/scopes/) or a scope under it gave. `build` makes content from them, here a sorted list.
        Each host has the keys of the other two:
      ''
      (docs.value result.flake.known)
      ''
        ## One owner per key
      ''
      (docs.fileNoted "" "modules/addresses.nix")
      ''
        At `(1)`, `claim` is the sink's `reduce`. Each key has one owner, and two owners is an error. At `(2)` every host
        gives its address. When a new host takes the nas's address, the fleet has an error and no outputs:
      ''
      (docs.value (
        map (e: {
          inherit (e)
            error
            code
            from
            sink
            ;
        }) (variant "variants/clash.nix").errors
      ))
      ''
        With `rank`, the highest value wins and there's no error, for example `rank = claim: claim.priority` when two
        virtual machines ask for one GPU.

        ## Sections from many files
      ''
      (docs.fileNoted "" "modules/readme.nix")
      ''
        At `(1)`, `ordered` is the sink's `reduce`. Its elements are `{ name; value; before; after; }`, and it finds
        an order that meets all of them. `(2)` puts a section after `intro`, and `(3)`, written in another file, goes between the two:
      ''
      (docs.value result.flake.readme)
      ''
        A cycle, a name given twice, or an unknown name in `before` or `after` is an error.

        ## Other module systems

        A sink can collect modules of any module system: NixOS, flake-parts, sini/files, or plain `lib.evalModules`.
      ''
      (docs.fileNoted "" "modules/modules.nix")
      ''
        `(1)`, `configurations`, gives one flake output per scope, `<output>.<scope name>`, from a builder you pass
        (`nixosSystem`, `darwinSystem`, any function). `(2)`, `eval-modules`, evaluates the modules with fixed modules
        first. `(3)`, `imports`, turns a sink of modules into one module for another sink. Here's what they give:
      ''
      (docs.value {
        inherit (result.flake) settings report;
      })
      ''
        ## Write your own

        A battery is a plain Nix function, so if none fits, write one in your fleet. Use the same shape and it stays as
        reusable as these:

        - Take the sinks you read as refs, like `from = yen.kinds.fleet.sinks.keys`, and read them with
          `sinks.''${from.__sink}`.
        - Read the scope with `scope`, never with an arg named after a kind.
        - Return a value. Don't write `yen.kinds.…` or `yen.aspects.…` keys, since those are the user's names.

        This is all of `mesh`:
      ''
      (docs.nix ''
        mesh =
          { from, build }:
          { scope, sinks, ... }:
          build (map (e: e.value) (builtins.filter (e: !own scope e) sinks.''${from.__sink}));
      '')
      ''
        ## All the generic batteries

        | Battery | Value of | Does |
        |---|---|---|
        | `mesh { from; build; }` | any key of an [aspect](/behavior/aspects/) | the records of sink `from`, except the ones that this scope or a scope under it gave; `build` makes content of them |
        | `claim { key; rank ? ; }` | `reduce` of a sink | each key has one owner; two owners is an error, unless `rank` picks one |
        | `ordered` | `reduce` of a sink | elements `{ name; value; before; after; }` in an order that meets all of them |
        | `perSystem.out { from; group; systemOf ? ; }` | `out` of a sink at a system scope | the reduced sink as flake output `<group>.<system>` |
        | `perSystem.inputs { inputs; system; }` | anywhere | each input read at one system: `packages.<system>` over `legacyPackages.<system>`, so `(…).nixpkgs.hello` |
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
      mesh = eq (result.flake.known) ({
        desk = [
          "ssh-ed25519 AAAAlaptop"
          "ssh-ed25519 AAAAnas"
        ];
        laptop = [
          "ssh-ed25519 AAAAdesk"
          "ssh-ed25519 AAAAnas"
        ];
        nas = [
          "ssh-ed25519 AAAAdesk"
          "ssh-ed25519 AAAAlaptop"
        ];
      });
      claim = eq (result.flake.addrs) ([
        "10.0.0.1"
        "10.0.0.2"
        "10.0.0.3"
      ]);
      clash = {
        t1 = eq (map (e: e.code) (variant "variants/clash.nix").errors) ([ "claim" ]);
        t2 = eq (builtins.attrNames (variant "variants/clash.nix").flake) ([
          "checks"
          "invalid-flake-errors"
        ]);
      };
      ordered = eq (result.flake.readme) ("# My fleet\n## Usage\n## Hosts");
      eval-modules = {
        t1 = eq (result.flake.settings.nas.ssh) ({
          port = 22;
          ciphers = [ "chacha20" ];
        });
        t2 = eq (result.flake.settings.desk.ssh) ({ port = 22; });
      };
      report = eq (builtins.sort builtins.lessThan result.flake.report.hosts) ([
        "desk"
        "laptop"
        "nas"
      ]);
      imports = eq (result.flake.notes.imports) ([ "note" ]);
    };
}
