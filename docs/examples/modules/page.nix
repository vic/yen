let
  # nixpkgs composite types check only the outer shape: each is true on a bad item; a leaf type checks it
  shallowIn = t: {
    list = (t.listOf t.int).check [ "a" ];
    attrs = (t.attrsOf t.int).check { x = "a"; };
    submodule = (t.submodule { options = { }; }).check { y = 1; };
    function = (t.functionTo t.int).check (x: "a");
    leaf = t.int.check "a";
  };
  shallow = inputs: shallowIn inputs.nixpkgs.lib.types;
in
{
  title = "Yen modules are not NixOS modules";
  description = "A Yen module has `imports`, `yen` and sinks, and Yen doesn't use nixpkgs. Each NixOS pattern, and how to write it in Yen.";
  section = "principles";
  order = 4;

  body =
    {
      docs,
      result,
      variant,
      inputs,
      ...
    }:
    [
      ''
        A Yen module looks like a NixOS module (a path, a function or an attrset, with `imports`), but it isn't one.
        Yen doesn't use the NixOS module system and doesn't depend on nixpkgs; it uses only Nix builtins.
        A module is a function `sources -> sinks`, like in [Cycle](/behavior/cycle/). This module has all three kinds of key:
      ''
      (docs.fileNoted "" "variants/module-sinks.nix")
      ''
        - `imports` `(4)`: more Yen modules.
        - `yen` `(1)`: every declaration. Here it declares a sink.
        - any other key `(5)`: a module sink, like `admins`, `lib` or `inputs`. Any module reads a sink as an arg, as at `(6)`.

        There's no `options` and no `config`. A sink that no module reads or declares is an error, and so is a
        key Yen doesn't read inside `yen` or inside a [kind](/model/kinds-fields/). This NixOS module has both keys:
      ''
      (docs.file "variants/nixos-style.nix")
      (docs.value (map (e: { inherit (e) code error path; }) (variant "variants/nixos-style.nix").errors))
      ''
        ## Module sinks: the options of a module

        `yen.sinks.<name>` declares a module sink, like a top-level `options` does in NixOS. In the module above, `(1)` declares
        `admins`. Its keys are the same as a kind's [sink](/behavior/sinks/): `of` `(2)` is the type that checks each module's
        value, and `reduce` `(3)` is the merge strategy. A sink with no `reduce` takes `one` value, which an arg gets as it is,
        and a declared sink that no module gives reduces to its empty value. The two `admins` lists reach the `wheel` aspect as one list:
      ''
      (docs.value (variant "variants/module-sinks.nix").reduced.nixos."fleet:main/host:web".users)
      ''
        Key names load before any arg has an answer, so a key name that reads an arg is an error record. `imports` can read
        a sink like `inputs` when modules outside its own imports give it, and Yen loads such imports in rounds.
        `result.modules` (see [Queries](/query/queries/)) shows what each module asks, gives and declares. A cycle in it is
        `import-loop`, an error record, not an infinite recursion.
      ''
      ''
        ## What Yen gets from not using nixpkgs modules

        - **A loop is data.** In nixpkgs, a module whose `imports` reads `config` stops the evaluation with
          `infinite recursion encountered`. In Yen, an `imports` that asks a sink its own imports give is an
          `import-loop` error record, and the rest of the fleet still evaluates.
        - **A type error is data, and it names the file.** In nixpkgs a wrong value throws, and only the first throw
          shows. In Yen a value that fails `of` is an error record with the module that gave it, and Yen drops that value
          and keeps going, so you see every error in one pass.
        - **Validation is apart from merging.** `of` only checks and `reduce` only merges. A nixpkgs type does both,
          and a composite type only checks its items in `merge` (see the caution below).
        - **No priorities.** There's no `mkDefault` or `mkForce`. Two different answers are an error with a `fix`, because
          data never overrides data.
        - **One concept for args and options.** `specialArgs`, `_module.args` and `options` are all module sinks. A sink
          without a declaration gives its value as it is, like `lib` or `inputs`.
        - **The loader is data.** `result.modules` shows what each module asks, gives and declares, and which module
          imports it, and Yen queries and graphs read it.
        - **No dependency.** Yen modules use only Nix builtins, so they don't need nixpkgs `lib`.

        nixpkgs modules still have more: NixOS, home-manager and nix-darwin are written for them, and Yen uses those
        modules inside sink elements. nixpkgs also has `mkIf` on `config`, where Yen has an aspect's `at`.

        ## Types: anything with `check`

        A field type is any value with `check = v: bool`. Yen ships the common ones and needs no nixpkgs:

        - `yen.lib.str`, `int`, `bool`, `port`, `path`, `attrs`, `any`, and `enum`, `maybe`, `listOf`, `attrsOf`,
          `functionTo`. A field checks the shape of a list, an attrset or a function, and `result.deep` checks the parts.
        - `yen.lib.is f`: any predicate, for example `yen.lib.is builtins.isString`.
        - nixpkgs types work as a predicate, but not for composites (read the warning below).
        - [nix-effects](https://github.com/kleisli-io/nix-effects) types: `Int`, `ListOf`, `Record`, refinements.
        - [gen-types](https://github.com/sini/gen) checkers, through their `verify`.

        Yen keeps validation apart from merging. A type only checks a value, and how many values become one is the
        sink's `reduce`, its merge strategy (see [Sinks](/behavior/sinks/)). A nixpkgs type does both, in `check` and
        `merge`, and Yen only calls `check`.
      ''
      (docs.caution "nixpkgs composite types don't check their items" ''
        In nixpkgs, `listOf`, `attrsOf`, `submodule` and `functionTo` only check the outer shape. The items are
        checked in `merge`, which Yen never calls. So in nixpkgs, `(lib.types.listOf lib.types.int).check` accepts a list of
        strings:

        ${docs.nix ''
          (lib.types.listOf lib.types.int).check [ "a" ]          # ${builtins.toJSON (shallow inputs).list}
          (lib.types.attrsOf lib.types.int).check { x = "a"; }    # ${builtins.toJSON (shallow inputs).attrs}
          (lib.types.submodule { options = { }; }).check { y = 1; } # ${builtins.toJSON (shallow inputs).submodule}
          (lib.types.functionTo lib.types.int).check (x: "a")     # ${builtins.toJSON (shallow inputs).function}
        ''}
        Use nixpkgs leaf types (`str`, `int`, `bool`, `port`, `enum`, `nullOr`) freely. For a list or an attrset
        whose items matter, use nested fields with a leaf type at each leaf, or a type that checks deep.
      '')
      ''
        nix-effects types check deep, and the kernel can build a check for you: `verified.verify` type-checks an
        implementation against its specification and gives a plain Nix function, and that function is a check:
      ''
      (docs.nix ''
        let
          inherit (fx.types) ListOf Int Record hoas verified;
          H = hoas;
          v = verified;
          # String -> [String] -> Bool, verified by the kernel, extracted as a plain Nix function
          strElem = v.verify (H.forall "t" H.string (_: H.forall "xs" (H.listOf H.string) (_: H.bool))) (
            v.fn "t" H.string (t: v.fn "xs" (H.listOf H.string) (xs: v.strElem t xs))
          );
        in
        {
          yen.kinds.host.fields = {
            ports = ListOf Int; # [ "a" ] fails `check`
            owner = Record { name = fx.types.String; };
            target = yen.lib.is (t: strElem t [ "module" "file" "package" ]); # "fleet" fails `check`
          };
        }
      '')
      ''
        A gen-types checker has `verify`, which gives `null` or the reason a value fails. Its `check` follows the
        nixpkgs protocol and isn't `v: bool`, so give Yen a check made from `verify`:
      ''
      (docs.nix ''
        yen.kinds.host.fields.ports = yen.lib.is (v: (gen.listOf gen.int).verify v == null);
      '')
      ''
        ## Each NixOS pattern, in Yen

        The kinds hold what NixOS `options` hold, and the instances hold what `config` holds:
      ''
      (docs.fileNoted "" "modules/kinds.nix")
      ''
        At `(1)`, `addr` is a field, just like an option has a type. At `(2)`, a nested field with a default is the answer to
        `mkEnableOption`. At `(3)`, `listOf` checks every item, and at `(4)`, `spawns.user` makes each user a scope under its host.
        At `(5)` the `nixos` sink collects the NixOS modules, and at `(6)` `on` is a ref from a user to its host.
        The instances hold the `config`:
      ''
      (docs.fileNoted "" "modules/fleet.nix")
      ''
        At `(1)` the flake has no outputs, because this page reads the eval result. At `(2)` and `(3)` instance data
        takes the place of `config`, and at `(4)` `at` takes the place of `mkIf`. This table lists each NixOS pattern:
      ''
      (docs.table
        [ "NixOS" "Yen" ]
        [
          [
            "`options.x = mkOption { type; default; }`"
            "`yen.kinds.K.fields.x = yen.lib.opt type default`"
          ]
          [
            "a top-level option that many modules set, such as `flake.lib`"
            "a module sink: `yen.sinks.x = { of = type; reduce = …; }`, then `x = v;` in each module"
          ]
          [
            "`mkEnableOption`"
            "a nested field: `fields.firewall.enable = yen.lib.opt yen.lib.bool false`"
          ]
          [
            "`default = f config`"
            "`yen.lib.derive type f`: see [Types](/model/types/)"
          ]
          [
            "`config.x = v`"
            "instance data: `yen.host.web.x = v`"
          ]
          [
            "`mkIf config.firewall.enable`"
            "`at = yen.lib.all [ yen.kinds.host (s: s.firewall.enable) ]`"
          ]
          [
            "list and attrset options from many modules"
            "a sink with a `reduce`: see [Sinks](/behavior/sinks/)"
          ]
          [
            "`mkDefault`, `mkForce`"
            "a type default, then the instance value. Two values for one leaf are `two-answers`"
          ]
          [
            "`assertions`"
            "`yen.invariants`, or an aspect's `errors` key"
          ]
          [
            "`imports`, `specialArgs`"
            "`imports`, and the sinks of the root module: `inherit inputs lib;`"
          ]
          [
            "`attrsOf (submodule { … })`"
            "a kind with instances, below"
          ]
        ]
      )
      (docs.value result.reduced.nixos)
      (docs.note "Guard `at` with the kind" ''
        `at` runs at every scope, so `s: s.firewall.enable` alone fails at the fleet scope, which has no `firewall`.
        `yen.lib.all [ yen.kinds.host … ]` only reads the field on hosts.
      '')
      ''
        ## Submodules

        In NixOS, `users.users.<name>` and `services.nginx.virtualHosts.<name>` are `attrsOf (submodule { … })`:
        a module inside each value, with its own options. `submoduleWith` adds args and more modules to each one.
        Each value is merged into one attrset, and it has no identity outside its parent.

        In Yen, a named submodule is a kind, like `user` above. Each user is an instance with a name, a ref to
        its host (`on = yen.kinds.host`), defaults (`shell`), and its own errors with a path. `spawns` makes each
        user a scope under its host, so aspects can be active on users and queries can find them:
      ''
      (docs.value (map (s: s.id) result.scopes))
      ''
        A submodule with no names, like `services.nginx`, is a nested field, as `firewall.enable` and `firewall.ports`
        are above. To see how `config` as a fixpoint compares, read [Fixpoints and dependencies](/principles/fixpoints/).
      ''
    ];

  checks =
    {
      result,
      variant,
      inputs,
      eq,
      yes,
      no,
      ...
    }:
    {
      nixos-style = eq (map (e: e.code) (variant "variants/nixos-style.nix").errors) ([
        "unread-sink"
        "unread-sink"
      ]);
      module-sinks = {
        value =
          eq
            (variant "variants/module-sinks.nix").reduced.nixos."fleet:main/host:web".users.groups.wheel.members
            [
              "ana"
              "bo"
            ];
        errors = eq (variant "variants/module-sinks.nix").errors [ ];
      };
      mkif = {
        t1 = yes (result.active.firewall."fleet:main/host:web");
        t2 = no (result.active.firewall."fleet:main/host:db");
      };
      nixos = eq (result.reduced.nixos) ({
        "fleet:main/host:web".networking.firewall.allowedTCPPorts = [ 443 ];
      });
      submodule-as-kind = eq (map (s: s.id) result.scopes) ([
        "fleet:main"
        "fleet:main/host:db"
        "fleet:main/host:web"
        "fleet:main/host:web/user:ana"
      ]);
      default = eq ((builtins.head (builtins.filter (s: s.kind == "user") result.scopes)).shell) ("bash");
      # the warning is true: nixpkgs composite types check only the outer shape
      nixpkgs-shallow = eq (shallow inputs) {
        list = true;
        attrs = true;
        submodule = true;
        function = true;
        leaf = false;
      };
    };
}
