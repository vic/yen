{
  title = "Aspects";
  description = "Behavior at scopes. An aspect is active where `at` holds, and gives elements to sinks by key.";
  section = "behavior";
  order = 1;

  body =
    { docs, result, ... }:
    [
      ''
        An aspect is one feature. It is active at every [scope](/model/scopes/) where its `at` predicate holds.
        Each other key gives one element to the [sink](/behavior/sinks/) of that name. The element is a value, or a function
        that asks for args (see [Args](/behavior/args/)).

        In this example, hosts collect `packages`. Users live under hosts and have no `packages` sink,
        so the packages of a user go up to its host.
      ''
      (docs.file "modules/fleet.nix")
      ''
        ## One aspect, many files

        `at` from several files is a union. The keys of every file apply wherever the aspect is active:
      ''
      (docs.tabs [
        {
          label = "nginx/web.nix";
          body = docs.file "modules/nginx/web.nix";
        }
        {
          label = "nginx/db.nix";
          body = docs.file "modules/nginx/db.nix";
        }
      ])
      ''
        `nginx` is active at both hosts, never at the users. Read it with `result.active.nginx`:
      ''
      (docs.value result.active.nginx)
      ''
        ## Aspects a kind or an instance owns

        A kind can own aspects, as it owns nested kinds: `yen.kinds.host.aspects.ssh = { … };`. By default the aspect
        runs on every scope of its kind, the way a nested kind is spawned by default; an explicit `at` replaces that
        default. A nested kind owns its own: `yen.kinds.host.kinds.user.aspects.shell`.

        A self-contained part, such as a [kit](/batteries/kits/), keeps its aspects in its own instance:
        `yen.kit.disko.aspects.default = { at = …; … };`.

        An owned aspect is named by its declaration path, as a nested kind is: `[ "kinds" "host" "aspects" "ssh" ]`,
        `[ "kit" "disko" "aspects" "default" ]`. Its ref follows the same path: `yen.kinds.host.aspects.ssh`,
        `yen.kit.disko.aspects.default`. An aspect that `yen.aspects` names cannot start with `[` (the error
        `reserved`), so no aspect of the fleet can take the name of an owned one.

        ## Static content lands once

        Static content counts once per receiver. `zsh` is active at `web` and at its two users, and `web` gets one `zsh`.
        Content that names the scope (`{ user, ... }:`) lands once per scope: each user gives its own dotfiles.
      ''
      (docs.file "modules/shells.nix")
      (docs.value result.flake.packages)
      (docs.caution "Aspects do not flow down" ''
        An aspect is active only where `at` holds. It never reaches the children of that scope:
        a host profile does not reach the users or guests of the host. Elements go up, never down.
      '')
      (docs.tip "Static or function?" ''
        Use a static value for data that all receivers share. Use a function value for data that each scope owns.
      '')
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
      union = {
        t1 = yes (result.active.nginx."fleet:main/host:web");
        t2 = yes (result.active.nginx."fleet:main/host:db");
        t3 = no (result.active.nginx."fleet:main/host:web/user:bob");
      };
      zsh-once = eq (builtins.length (builtins.filter (p: p == "zsh") result.flake.packages.web)) (1);
      dotfiles = {
        t1 = yes (builtins.elem "dotfiles-alice" result.flake.packages.web);
        t2 = yes (builtins.elem "dotfiles-bob" result.flake.packages.db);
      };
    };
}
