{
  title = "Args";
  description = "An element can be a function with named args. Yen fills kinds, sinks and `scope`, and other args stay open.";
  section = "behavior";
  order = 7;

  body =
    {
      docs,
      result,
      variant,
      ...
    }:
    [
      ''
        An element can be a function with named args, and Yen fills in the args it knows. In this example, a load
        balancer reads the addresses its environment collects. First, the [kinds](/model/kinds-fields/) and
        [sinks](/behavior/sinks/) it reads:
      ''
      (docs.fileNoted "" "modules/fleet.nix")
      ''
        `(1)` is the `environment` kind's `backends` sink, where hosts give their address, and `(2)` is the `host` kind's
        `proxy` sink. Now the [aspects](/behavior/aspects/), whose elements are functions with args:
      ''
      (docs.fileNoted "" "modules/aspects.nix")
      ''
        `(1)` asks for `host`, the name of a kind, and `(2)` names a kind too. `(3)` names a sink, and `(4)` is `scope`.
        `(5)` has a default, so it's optional. Here's what the balancer gives:
      ''
      (docs.value result.flake.proxy)
      ''
        ## The args Yen fills

        The rules:
      ''
      (docs.table
        [ "Arg" "Value" ]
        [
          [
            "a [kind](/model/kinds-fields/) name (`host`, `environment`)"
            "the nearest ancestor-or-self [scope](/model/scopes/) of that kind"
          ]
          [
            "a [sink](/behavior/sinks/) name (`backends`)"
            "the reduced value of that sink at its nearest receiver"
          ]
          [
            "`scope`"
            "the scope itself"
          ]
          [
            "anything else (`pkgs`, `config`)"
            "stays open: the element is still a function"
          ]
        ]
      )
      ''
        ## Optional and missing args

        `{ cluster ? null, ... }` makes an arg optional. Without a default, an arg with no answer means the element isn't
        given at all. Add this file to the example:
      ''
      (docs.fileNoted "" "variants/missing.nix")
      ''
        `(1)` needs a `cluster`, and no scope here is under one. `errors` tells you why:
      ''
      (docs.value (variant "variants/missing.nix").errors)
      ''
        ## Open args: modules for NixOS and home-manager

        Args Yen doesn't know stay open, and that's how a `nixos` element can be a NixOS module. In this file Yen fills
        `host`, and the element stays a function of `pkgs`. NixOS fills `pkgs`, `config` and `lib` later.
      ''
      (docs.fileNoted "" "variants/open.nix")
      ''
        `(1)` has the arg `host`, which Yen fills, and the arg `pkgs`, which stays open.
      ''
      (docs.caution "Overlays" ''
        A bare `final: prev:` is a function of `final`, and Yen has no `final`, so it's an error. Wrap it:
        `{ ... }: final: prev: …`.
      '')
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
      proxy = eq (result.flake.proxy.lb) ([
        {
          at = "fleet:main/environment:prod/host:lb";
          backends = [
            "10.0.0.2"
            "10.0.0.3"
          ];
          cluster = "none";
          env = "prod";
        }
      ]);
      missing = eq (builtins.length (variant "variants/missing.nix").errors) (1);
      open = yes (
        builtins.isFunction (builtins.elemAt (variant "variants/open.nix").flake.proxy.lb 1)
        || (builtins.elemAt (variant "variants/open.nix").flake.proxy.lb 1) ? __functor
      );
    };
}
