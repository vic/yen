{
  title = "Args";
  description = "An element can be a function with named args. yen fills kinds, sinks and `scope`; other args stay open.";
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
        An element can be a function with named args. yen fills the args it knows.
        In this example, a load balancer reads the addresses that its environment collects.
        First the [kinds](/model/kinds-fields/) and [sinks](/behavior/sinks/) it reads:
      ''
      (docs.fileNoted "" "modules/fleet.nix")
      ''
        `(1)` is the sink `backends` of `environment`. Hosts give their address to it. `(2)` is the sink `proxy` of `host`.
        Now the [aspects](/behavior/aspects/). Their elements are functions with args:
      ''
      (docs.fileNoted "" "modules/aspects.nix")
      ''
        `(1)` asks for `host`, the name of a kind. `(2)` also names a kind. `(3)` names a sink.
        `(4)` is `scope`. `(5)` has a default, so it is optional. This is what the balancer gives:
      ''
      (docs.value result.flake.proxy)
      ''
        ## The args yen fills

        These are the rules:
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

        `{ cluster ? null, ... }` makes an arg optional. Without a default, an arg with no answer means the element
        is not given. Add this file to the example:
      ''
      (docs.fileNoted "" "variants/missing.nix")
      ''
        `(1)` needs a `cluster`, and no scope here is under one. `errors` says why:
      ''
      (docs.value (variant "variants/missing.nix").errors)
      ''
        ## Open args: modules for NixOS and home-manager

        Args that yen does not know stay open. This is how a `nixos` element is a NixOS module. In this file, yen
        fills `host` and the element stays a function of `pkgs`. NixOS fills `pkgs`, `config` and `lib` later.
      ''
      (docs.fileNoted "" "variants/open.nix")
      ''
        `(1)` has the arg `host`, which yen fills, and the arg `pkgs`, which stays open.
      ''
      (docs.caution "Overlays" ''
        A bare `final: prev:` is a function of `final`, and yen has no `final`. That is an error.
        Wrap it: `{ ... }: final: prev: …`.
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
