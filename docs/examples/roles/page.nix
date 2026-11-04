{
  title = "Roles from data";
  description = "A role is an aspect whose `at` tests a fact. No host file lists its roles.";
  section = "recipes";
  order = 2;

  body =
    { docs, result, ... }:
    [
      ''
        Host files that list roles drift: someone adds a GPU and forgets the line. Put the facts on the host instead,
        and let each role test them. A host has these facts as [fields](/model/kinds-fields/):
      ''
      (docs.fileNoted "{12-17}" "modules/kinds.nix")
      ''
        At `(1)`, `form` is one of three words. At `(2)`, `gpu` is `"none"` unless the host says otherwise. At `(3)`, `labels` is a
        list of strings. At `(4)`, `rack-1` has the label `ci-runner`. A role is an [aspect](/behavior/aspects/) whose `at` is a
        [predicate](/behavior/predicates/) of these facts:
      ''
      (docs.fileNoted "" "modules/roles.nix")
      ''
        At `(1)`, `server` is active at every host with `form` set to `"server"`. At `(2)`, roles combine like any predicate:
        `gaming` is a workstation with an nvidia GPU that is not a laptop. At `(3)`, a list means any of its members.
        A role gives content with the usual keys (`nixos`, `homeManager`, …), and other aspects can use it in `at`.

        ## Tags for deploy tools

        `yen.lib.holds` asks a predicate at a scope. One aspect turns the active roles into tags:
      ''
      (docs.fileNoted "" "modules/tags.nix")
      ''
        At `(1)`, `holds` asks each role at the scope of the host. The tags:
      ''
      (docs.value result.flake.tags)
      (docs.tip "Change a fact, not a list" ''
        Give `rack-2` the label `ci-runner`, and it gets the role, its content and its tag. Nothing else changes.
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
      tags = eq (result.flake.tags) ({
        rack-1 = [
          "server"
          "ci-runner"
          "backups"
        ];
        rack-2 = [
          "server"
          "backups"
        ];
        thinkpad = [
          "workstation"
          "laptop"
          "backups"
        ];
        tower = [
          "workstation"
          "nvidia"
          "gaming"
          "backups"
        ];
      });
    };
}
