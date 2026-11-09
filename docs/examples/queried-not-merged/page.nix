{
  title = "Data is queried, not merged";
  description = "Each read is a query on the files that answer it. Two answers for one leaf are an error, not an override.";
  section = "principles";
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
        The NixOS module system merges every definition into one value and then reads it. Yen doesn't merge: reading a
        path is one [query](/query/queries/) on the files that answer that path.

        Here two feature files declare settings at two paths of the same field, and neither file knows about the other:
      ''
      (docs.tabs [
        {
          label = "features/zfs.nix";
          body = docs.fileNoted "" "modules/features/zfs.nix";
        }
        {
          label = "features/k3s.nix";
          body = docs.fileNoted "" "modules/features/k3s.nix";
        }
      ])
      ''
        In `zfs.nix`, `(1)` declares the field `settings.zfs.arcMax` on every [host](/model/kinds-fields/), and `(2)`
        declares the same path on the `environment` kind. In `k3s.nix`, `(1)` declares `settings.k3s.role` with the
        default `"agent"`.

        Reading `host.settings.k3s.role` looks at the instance, then at the type default, and never reads `zfs.nix`.
        `result.declaredIn` tells you which files declare a path:
      ''
      (docs.value (
        map baseNameOf (
          result.declaredIn [
            "kinds"
            "host"
            "fields"
            "settings"
          ]
        )
      ))
      ''
        ## Cascades

        These hosts take a value from their own settings, or from their environment:
      ''
      (docs.fileNoted "" "modules/hosts.nix")
      ''
        At `(1)`, a host has a ref to an `environment`. At `(2)`, the `prod` environment sets `arcMax`, and at `(3)`,
        `nas` sets its own while `node` sets none. This [aspect](/behavior/aspects/) reads the value for each host:
      ''
      (docs.fileNoted "{10}" "modules/report.nix")
      ''
        A cascade is a list in the order you choose. At `(1)`, `yen.lib.cascade path xs` gives the first non-null value
        along `xs`, so `nas` uses its own `arcMax` and `node` falls back to its environment. At `(2)`, the aspect reads a
        helper (more on helpers below). The fleet's report:
      ''
      (docs.value result.flake.report)
      ''
        ## Helpers

        `yen.helpers` holds shared values and functions. It's an open namespace: any file can declare a key, and any
        module can read it from its `yen` arg, as `report.nix` does. The `k3sRole` key is declared here:
      ''
      (docs.fileNoted "" "modules/helpers.nix")
      ''
        Each fleet picks its own helpers, so Yen doesn't document them and the schema (see
        [Agent surface](/agents/agent-surface/)) doesn't list them. A helper is a declaration like any other, with one
        answer per key. A second file giving the same key makes two answers, because two functions are never equal:
      ''
      (docs.file "variants/helper-twice.nix")
      (docs.value (map (e: { inherit (e) code path; }) (variant "variants/helper-twice.nix").errors))
      ''
        ## Two answers are an error

        One leaf with two different values isn't an override. It's an error record, and you keep one of the answers:
      ''
      (docs.file "variants/override.nix")
      (docs.value (variant "variants/override.nix").errors)
      (docs.note "Same value, no error" ''
        Two files giving the same value for one leaf are fine, only a conflict is an error. Lists and attrsets for aspect
        keys are elements, not leaves, see [Aspects](/behavior/aspects/).
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
      cascade = eq (result.flake.report) ({
        nas = {
          arcMax = 32;
          k3s = "agent";
        };
        node = {
          arcMax = 8;
          k3s = "server";
        };
      });
      declared =
        eq
          (map baseNameOf (
            result.declaredIn [
              "kinds"
              "host"
              "fields"
              "settings"
            ]
          ))
          ([
            "k3s.nix"
            "zfs.nix"
          ]);
      two-answers = eq (map (e: e.code) (variant "variants/override.nix").errors) ([ "two-answers" ]);
      helper-twice =
        eq (map (e: { inherit (e) code path; }) (variant "variants/helper-twice.nix").errors)
          ([
            {
              code = "two-answers";
              path = [
                "helpers"
                "k3sRole"
              ];
            }
          ]);
    };
}
