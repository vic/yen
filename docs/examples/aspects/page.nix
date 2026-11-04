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

        First the fleet that the aspects below act on. Hosts have users:
      ''
      (docs.fileNoted "" "modules/fleet.nix")
      ''
        `(1)` is the `packages` sink of `host`: hosts collect `packages`. Users live under hosts and have no `packages` sink,
        so the packages of a user go up to its host.

        ## One aspect, many files

        `at` from several files is a union. The keys of every file apply wherever the aspect is active.
        The aspect `nginx` has one file for each host:
      ''
      (docs.tabs [
        {
          label = "nginx/web.nix";
          body = docs.fileNoted "" "modules/nginx/web.nix";
        }
        {
          label = "nginx/db.nix";
          body = docs.fileNoted "" "modules/nginx/db.nix";
        }
      ])
      ''
        `(1)` in `web.nix` puts `nginx` at the host `web`. `(2)` in `db.nix` puts it at the host `db`.
        `nginx` is active at both hosts, never at the users. Read it with `result.active.nginx`:
      ''
      (docs.value result.active.nginx)
      ''
        ## Aspects a kind or an instance owns

        A kind can own aspects, as it owns [nested kinds](/model/nested-kinds/): `yen.kinds.host.aspects.ssh = { … };`. By default the aspect
        runs on every scope of its kind, the way a nested kind is spawned by default; an explicit `at` replaces that
        default. A nested kind owns its own: `yen.kinds.host.kinds.user.aspects.shell`.

        A self-contained part, such as a [kit](/batteries/kits/), keeps its aspects in its own instance:
        `yen.kit.disko.aspects.default = { at = …; … };`. The real kit is
        [lib/kits/disko.nix](https://github.com/vic/yen/tree/main/lib/kits/disko.nix).

        An owned aspect is named by its declaration path, as a nested kind is: `[ "kinds" "host" "aspects" "ssh" ]`,
        `[ "kit" "disko" "aspects" "default" ]`. Its ref follows the same path: `yen.kinds.host.aspects.ssh`,
        `yen.kit.disko.aspects.default`. An aspect that `yen.aspects` names cannot start with `[` (the error
        `reserved`), so no aspect of the fleet can take the name of an owned one.

        ## Static content lands once

        Static content counts once per receiver. Content that names the scope lands once per scope.
        These two aspects show both:
      ''
      (docs.fileNoted "" "modules/shells.nix")
      ''
        `(1)` makes `zsh` active at hosts and at users. `(2)` is static: `zsh` is active at `web` and at its two users,
        and `web` gets one `zsh`. `(3)` names the scope (`{ user, ... }:`): each user gives its own dotfiles.
      ''
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
