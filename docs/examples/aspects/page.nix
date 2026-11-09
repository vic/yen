{
  title = "Aspects";
  description = "Behavior at scopes. An aspect is active where `at` holds, and gives elements to sinks by key.";
  section = "behavior";
  order = 1;

  body =
    { docs, result, ... }:
    [
      ''
        An aspect is one feature. It's active at every [scope](/model/scopes/) where its `at` predicate holds, and every
        other key gives one element to the [sink](/behavior/sinks/) with that name. The element is a value, or a function
        that asks for args (see [Args](/behavior/args/)).

        First, the fleet the aspects below act on, where hosts have users:
      ''
      (docs.fileNoted "" "modules/fleet.nix")
      ''
        `(1)` is the `host` kind's `packages` sink, so hosts collect `packages`. Users live under hosts and have no
        `packages` sink, so a user's packages go up to its host.

        ## One aspect, many files

        When several files set `at`, Yen takes the union, and the keys from every file apply wherever the aspect is
        active. The `nginx` aspect has one file for each host:
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
        `(1)` in `web.nix` puts `nginx` at the host `web`, and `(2)` in `db.nix` puts it at the host `db`. `nginx` is
        active at both hosts and never at the users. You can read it with `result.active.nginx`:
      ''
      (docs.value result.active.nginx)
      ''
        ## Aspects a kind or an instance owns

        A kind can own aspects, just like it owns [nested kinds](/model/nested-kinds/):
        `yen.kinds.host.aspects.ssh = { … };`. By default the aspect runs on every scope of its kind, the same way a
        nested kind is spawned by default, and an explicit `at` replaces that default. A nested kind owns its own, like
        `yen.kinds.host.kinds.user.aspects.shell`.

        A self-contained part, such as a [kit](/batteries/kits/), keeps its aspects in its own instance:
        `yen.kit.disko.aspects.default = { at = …; … };`. You can see the real kit in
        [lib/kits/disko.nix](https://github.com/vic/yen/tree/main/lib/kits/disko.nix).

        An owned aspect is named by its declaration path, just like a nested kind: `[ "kinds" "host" "aspects" "ssh" ]`,
        `[ "kit" "disko" "aspects" "default" ]`. Its ref follows the same path: `yen.kinds.host.aspects.ssh`,
        `yen.kit.disko.aspects.default`. A name in `yen.aspects` can't start with `[` (that's the `reserved` error), so
        no fleet aspect can take an owned aspect's name.

        ## Static content lands once

        Static content counts once per receiver, while content that names the scope lands once per scope. These two
        aspects show both:
      ''
      (docs.fileNoted "" "modules/shells.nix")
      ''
        `(1)` makes `zsh` active at hosts and users. `(2)` is static, so although `zsh` is active at `web` and at its two
        users, `web` gets a single `zsh`. `(3)` names the scope (`{ user, ... }:`), so each user gives its own dotfiles.
      ''
      (docs.value result.flake.packages)
      (docs.caution "Aspects do not flow down" ''
        An aspect is only active where `at` holds, and it never reaches that scope's children: a host profile doesn't
        reach the host's users or guests. Elements go up, never down.
      '')
      (docs.tip "Static or function?" ''
        Use a static value for data every receiver shares, and a function for data each scope owns.
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
