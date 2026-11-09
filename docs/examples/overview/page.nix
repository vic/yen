{
  title = "Overview";
  description = "What Yen is, in four words: kinds, scopes, aspects, sinks.";
  section = "start";
  order = 2;

  body =
    { docs, result, ... }:
    [
      ''
        Yen is a verified language for Nix configurations. You declare data and behavior in plain Nix files, and
        Yen checks them and answers with the systems to build, the errors, and the graph of who gives what to whom.

        Yen is one small Nix file that uses only Nix builtins: no nixpkgs, no module system, no flakes.
        It never calls `throw`, because an error is data you can prove.
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

        Everything in Yen is one of four words. Read them once, in order, before any code. The
        [glossary](/reference/glossary/) lists every Yen term.

        1. **[Kind](/model/kinds-fields/).** A type of thing you configure, and the fields each one has. You name your kinds: `host`, `user`,
           `cluster`, `printer`, `editor`. An **instance** is one thing of a kind, like `yen.host.web`
           ([instances](/model/instances-refs/)).
        2. **[Scope](/model/scopes/).** One instance at one place in a tree. A kind's `spawns` says which instances live under it, like a user
           under each host it logs in to, or a host under its environment. The kind nothing spawns is the root.
        3. **[Aspect](/behavior/aspects/).** One feature, like "ssh on" or "nginx with these sites". Its `at` is a predicate that says at which
           scopes it's active, and each of its other keys gives one **element**: a value, or a function of the data.
        4. **[Sink](/behavior/sinks/).** Where elements go. A kind declares sinks, an element goes up the tree to the nearest scope with a sink
           of the same name, and the sink reduces all its elements to one value: a list, a set, a merged attrset, a single value.

        So kinds say what exists, scopes say where it lives, aspects say what to do, and sinks say who collects the result.
        Sinks also build the outputs; a host's sink can call `nixosSystem` on the modules it collected.
      ''
      (docs.note "Domain independent, with batteries" ''
        The Yen engine knows no nouns. It has no `host`, no `user`, no `nixos` class and no NixOS or flake-parts options.
        You define the kinds, fields and sinks of what you configure, in your own language, so a fleet of NixOS hosts, a set
        of dev shells and a printer inventory all use the same four words.

        For reuse, [`yen.lib.batteries`](/batteries/) are functions from roles to a Yen module. You pass every name, so a battery never
        adds a word to your fleet. Domain batteries like `yen.lib.batteries.nixos` fill the roles with one domain's
        options, so Den's `define-user` is `yen.lib.batteries.nixos.define-user` here, not part of the engine.

        Every example in these docs declares its own kinds, so you can read each one top to bottom.
      '')
      ''
        ## The four words in one example

        This example has no NixOS. An office has two machines, and each machine collects a set of package names.

        **Kinds and scopes.** This file declares two kinds and the office data:
      ''
      (docs.fileNoted "" "modules/kinds.nix")
      ''
        At `(1)` the `office` kind spawns every machine, and since nothing spawns `office`, it's the root.
        At `(2)` a machine has an `owner` field, and at `(3)` it has a `packages` sink that reduces
        its elements with `set`. At `(4)` the sink builds the `inventory` output from the elements it collected,
        and at `(5)` the office instance exists.

        **Aspects.** This file gives the behavior:
      ''
      (docs.fileNoted "" "modules/aspects.nix")
      ''
        At `(1)` `basics` is active at every machine, and at `(2)` `design` is active only at `studio`.
        At `(3)` `versioned-assets` is active wherever `design` is active, because an aspect can be a predicate,
        and at `(4)` it gives `git` again.

        **Sinks.** Each aspect key gives one element to the sink with that name. Each machine's `packages` sink
        reduces its elements with `set`, so `git` arrives twice at `studio` but stays once:
      ''
      (docs.value result.reduced.packages)
      ''
        Here's the scope tree and the routed elements, drawn from `result.graph`:
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

        There's no `evalModules` fixpoint and no merge step. Each read of a declaration is a query on the files
        that answer it, and a value is computed only when something reads it. Yen follows
        [Cycle.js](https://cycle.js.org): a [cycle](/behavior/cycle/) reads sources and writes sinks, and Nix laziness closes the loop.
        Read more in [queried, not merged](/principles/queried-not-merged/) and [fixpoints](/principles/fixpoints/).
      ''
      (docs.note "Why another configuration language?" ''
        Yen covers every capability of [Den](https://github.com/denful/den), den-hoag and [clan](https://clan.lol)
        with these four words. On top of that it answers questions: [graph](/query/graphs/) queries, [Datalog](/query/datalog/) with a well-founded semantics,
        and [µKanren](/query/ukanren/) with constraints, all in pure Nix. An agent can [stage](/agents/stage/) a change and get it refused, with the reason,
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
