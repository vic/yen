{
  title = "Overview";
  description = "What yen is, in four words: kinds, scopes, aspects, sinks.";
  section = "start";
  order = 2;

  body =
    { docs, result, ... }:
    [
      ''
        yen is a verified language for Nix configurations. You declare data and behavior in plain Nix files.
        yen checks them and answers: the systems to build, the errors, and the graph of who gives what to whom.

        yen is one small Nix file. It uses Nix builtins only: no nixpkgs, no module system, no flakes.
        It never calls `throw`. An error is data that you can prove.
      ''
      (docs.cards [
        {
          title = "Kinds";
          icon = "seti:json";
          body = "Typed data. A `host`, a `user`, an `environment`: you declare what exists and which fields it has. [Read more](/model/kinds-fields/).";
        }
        {
          title = "Scopes";
          icon = "list-format";
          body = "Where things live. `spawns` places each instance in a tree: a user under a host, a host under an environment. [Read more](/model/scopes/).";
        }
        {
          title = "Aspects";
          icon = "puzzle";
          body = "Behavior. An aspect is active where its `at` predicate holds, and gives elements by key. [Read more](/behavior/aspects/).";
        }
        {
          title = "Sinks";
          icon = "random";
          body = "Where elements go. An element goes up to the nearest scope that collects it, and the sink reduces them. [Read more](/behavior/sinks/).";
        }
      ])
      ''
        ## The four words

        Everything in yen is one of four words. Read them once, in order, before any code.
        The [glossary](/reference/glossary/) lists every term of yen.

        1. **[Kind](/model/kinds-fields/).** A type of thing you configure, and the fields each one has. You name your kinds: `host`, `user`,
           `cluster`, `printer`, `editor`. An **instance** is one thing of a kind: `yen.host.web`
           ([instances](/model/instances-refs/)).
        2. **[Scope](/model/scopes/).** One instance at one place in a tree. A kind's `spawns` says which instances live under it: a user
           under each host it logs in to, a host under its environment. The kind that nothing spawns is the root.
        3. **[Aspect](/behavior/aspects/).** One feature: "ssh on", "nginx with these sites". Its `at` is a predicate that says at which scopes
           it is active. Its other keys each give one **element**: a value, or a function of the data.
        4. **[Sink](/behavior/sinks/).** Where elements go. A kind declares sinks. An element goes up the tree to the nearest scope with a sink
           of the same name, and the sink reduces all its elements to one value: a list, a set, a merged attrset, one value.

        So: kinds say what exists, scopes say where it lives, aspects say what to do, and sinks say who collects the result.
        Sinks also build the outputs: the sink of a host can call `nixosSystem` on the modules it collected.
      ''
      (docs.note "Domain independent, with batteries" ''
        The yen engine knows no nouns. It has no `host`, no `user`, no `nixos` class and no NixOS or flake-parts options.
        You define the kinds, fields and sinks of what you configure, in your own language. A fleet of NixOS hosts, a set
        of dev shells and a printer inventory use the same four words.

        For reuse, [`yen.lib.batteries`](/batteries/) are functions from roles to a yen module: you pass every name, so a battery never
        adds a word to your fleet. Domain batteries, such as `yen.lib.batteries.nixos`, fill the roles with one domain's
        options. Den's `define-user` is `yen.lib.batteries.nixos.define-user` here, not part of the engine.

        Every example in these docs declares its own kinds, so you can read each one top to bottom.
      '')
      ''
        ## The four words in one example

        This example has no NixOS. An office has two machines. Each machine collects a set of package names.

        **Kinds and scopes.** This file declares two kinds and the data of the office:
      ''
      (docs.fileNoted "" "modules/kinds.nix")
      ''
        At `(1)`, the kind `office` spawns every machine. Nothing spawns `office`, so it is the root.
        At `(2)`, a machine has an `owner` field. At `(3)`, it has a `packages` sink, and the sink reduces
        its elements with `set`. At `(4)`, the sink builds the `inventory` output from the elements it collected.
        At `(5)`, the office instance exists.

        **Aspects.** This file gives the behavior:
      ''
      (docs.fileNoted "" "modules/aspects.nix")
      ''
        At `(1)`, `basics` is active at every machine. At `(2)`, `design` is active at `studio` only.
        At `(3)`, `versioned-assets` is active wherever `design` is active: an aspect can be a predicate.
        At `(4)`, it gives `git` again.

        **Sinks.** Each aspect key gives one element to the sink of that name. The `packages` sink of each machine
        reduces its elements with `set`, so `git` arrives twice at `studio` and stays once:
      ''
      (docs.value result.reduced.packages)
      ''
        The scope tree and the routed elements, drawn from `result.graph`:
      ''
      (docs.tabs [
        {
          label = "Scopes";
          body = docs.scopes result;
        }
        {
          label = "Routed elements";
          body = docs.routes result;
        }
      ])
      ''
        ## Data is queried, not merged

        There is no `evalModules` fixpoint and no merge step. Each read of a declaration is a query on the files
        that answer it. A value is computed only when something reads it. yen follows
        [Cycle.js](https://cycle.js.org): a [cycle](/behavior/cycle/) reads sources and writes sinks, and Nix laziness closes the loop.
        Read more: [queried, not merged](/principles/queried-not-merged/) and [fixpoints](/principles/fixpoints/).
      ''
      (docs.note "Why another configuration language?" ''
        yen covers every capability of [Den](https://github.com/denful/den), den-hoag and [clan](https://clan.lol)
        with these four words. On top, it answers questions: [graph](/query/graphs/) queries, [Datalog](/query/datalog/) with a well-founded semantics,
        and [µKanren](/query/ukanren/) with constraints, all in pure Nix. An agent can [stage](/agents/stage/) a change and get it refused with the reason,
        before you deploy.
      '')
      (docs.links [
        {
          title = "Getting started";
          href = "/start/getting-started/";
          description = "One NixOS host, in four files.";
        }
        {
          title = "The reference fleet";
          href = "https://github.com/vic/yen/tree/main/reference";
          description = "Every capability, in one running specification.";
        }
      ])
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
      packages = eq (result.reduced.packages) ({
        "office:main/machine:reception" = [ "git" ];
        "office:main/machine:studio" = [
          "git"
          "gimp"
        ];
      });
      inventory = eq (result.flake.inventory.studio) ([
        "git"
        "gimp"
      ]);
    };
}
