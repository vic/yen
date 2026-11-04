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
        The NixOS module system merges every definition into one value, then reads it.
        yen does not merge. A read of a path is one [query](/query/queries/) on the files that answer that path.

        Here two feature files declare settings at two paths of one field. Neither file knows the other:
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
        In `zfs.nix`, `(1)` declares the field `settings.zfs.arcMax` of every [host](/model/kinds-fields/), and `(2)` declares
        the same path on the kind `environment`. In `k3s.nix`, `(1)` declares `settings.k3s.role` with the default `"agent"`.

        A read of `host.settings.k3s.role` looks at the instance, then at the type default. It never reads `zfs.nix`.
        `result.declaredIn` answers which files declare a path:
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
        At `(1)`, a host has a ref to an `environment`. At `(2)`, the environment `prod` sets `arcMax`. At `(3)`, `nas` sets its
        own. `node` sets none. This [aspect](/behavior/aspects/) reads the value for each host:
      ''
      (docs.fileNoted "{10}" "modules/report.nix")
      ''
        A cascade is a list in your order. At `(1)`, `yen.lib.cascade path xs` gives the first non-null value along `xs`.
        `nas` has its own `arcMax`; `node` falls back to its environment. At `(2)`, the aspect reads a helper (see Helpers below). The report of the fleet:
      ''
      (docs.value result.flake.report)
      ''
        ## Helpers

        `yen.helpers` holds shared values and functions. It is an open namespace: any file declares a key, and any
        module reads it from its `yen` arg, as `report.nix` does. The key `k3sRole` is declared here:
      ''
      (docs.fileNoted "" "modules/helpers.nix")
      ''
        A fleet chooses its own helpers, so yen does not document them and the schema (see [Agent surface](/agents/agent-surface/)) does not list them.
        A helper is a declaration like any other: one answer per key. A second file that gives the same key is
        two answers, because two functions are never equal:
      ''
      (docs.file "variants/helper-twice.nix")
      (docs.value (map (e: { inherit (e) code path; }) (variant "variants/helper-twice.nix").errors))
      ''
        ## Two answers are an error

        One leaf with two different values is not an override. It is an error record, and you keep one answer:
      ''
      (docs.file "variants/override.nix")
      (docs.value (variant "variants/override.nix").errors)
      (docs.note "Same value, no error" ''
        Two files that give the same value for one leaf are fine. Only a conflict is an error.
        Lists and attrsets for aspect keys are elements, not leaves: see [Aspects](/behavior/aspects/).
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
