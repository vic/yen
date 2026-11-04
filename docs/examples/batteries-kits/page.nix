{
  title = "Kits batteries";
  description = "Kits and assemblies: members by `at` predicates, layered settings, exports, contracts, vars generators and their plan.";
  section = "batteries";
  route = "batteries/kits";
  order = 4;

  body =
    {
      docs,
      result,
      variant,
      ...
    }:
    [
      ''
        A kit is data: it has roles, each role has typed settings, members export values to each other, and kits
        declare the secrets they generate. An assembly is one use of a kit: its `kit` is a ref, and each role takes the
        machines where its `at` predicate holds, the same predicates an [aspect](/behavior/aspects/) uses. See
        [Assemblies and roles](/recipes/assemblies/) for the model by hand, and the [glossary](/reference/glossary/) for the words.
        You keep the words: here the machine [kind](/model/kinds-fields/) is `machine` and the member kind is `member`.

        This example has a `borg` backup kit with a server and clients, one assembly of it, and the rules that connect them.
      ''
      (docs.fileNoted "" "modules/inventory.nix")
      ''
        - `(1)` gives each machine one `member` [scope](/model/scopes/) for each (assembly, role) it takes. Settings are layered: the interface default, then the role's.
        - `(2)` and `(3)` are the fields of a kit and of an assembly. The `kit` of an assembly is a ref.
        - `(4)` is the `reduce` of the `exports` [sink](/behavior/sinks/). Members write their own element, and an export that the kit does not list is an error.
        - `(5)` is the kit. It has two roles, a typed interface for the client, a limit of one server, and the export `endpoint`.
        - `(6)` is the assembly. The server is any machine with `storage`. The `settings` of the client role are a function of the machine.
        - `(7)` checks the kits, assemblies and machines. It reports a kit that is no kit, an unknown role, an `at` that is no predicate, and a role with too many or too few machines.
        - `(8)` checks that every setting of a member is set and has its type.
        - At `(9)`, the server exports its endpoint. At `(10)`, each client reads the exports of its own assembly.

        A kit adds no name outside itself: its data are values of the kit (`yen.kit.disko.layouts`), its aspects live
        in the kit ([`yen.kit.sshd.aspects.server`](/behavior/aspects/#aspects-a-kind-or-an-instance-owns)), and the
        assemblies it adds are parts of the assembly that adds them. Each client reads the server's endpoint from the exports of its assembly, with its own settings:
      ''
      (docs.value result.flake.config)
      ''
        ## Vars

        A kit also declares the secrets it generates. A generator says which files a secret has, and which are secret.
        The plan says, for each machine, where each file goes and who can read it.
      ''
      (docs.fileNoted "" "modules/vars.nix")
      ''
        `(1)` reduces the generators of every machine: a shared generator once, the rest for each machine. A missing dependency is an error.
        `(2)` is the plan for each machine: secret files with their paths, recipients and generation order. `(3)` reads a public var at eval time, with a default.
        `(4)` reports an eval-time read of a secret file. This is the plan of `web`:
      ''
      (docs.value result.flake.varsPlan.web.files)
      ''
        ## The contract

        borg allows one server. A second machine with `storage` makes two:
      ''
      (docs.value (map (e: e.error) (variant "variants/two-servers.nix").errors))
      ''
        A name is not a ref. A string where the kit goes, and a string where a role's machines go, are errors:
      ''
      (docs.file "variants/by-name.nix")
      (docs.value (map (e: e.error) (variant "variants/by-name.nix").errors))
      ''
        ## The batteries

        The batteries of `yen.lib.batteries.kits`:

        | Battery | Value of | Does |
        |---|---|---|
        | `members { assemblies; holds; }` | `spawns.<member kind>` of a machine kind | one member per (assembly, role), with refs to its assembly and kit; settings layered: interface default, then the role's (attrs, or a function of the machine) |
        | `exports { isMember; }` | `reduce` of the exports sink | members write their own element; another scope overrides an entry by refs; an unlisted export is an error |
        | `contract { assemblies; machines; holds; }` | `errors` | a kit that is no kit, an unknown role, an `at` that is no predicate, no roles, min and max machines per role, `maxAssemblies`, two assemblies with one name |
        | `assemblies own` | a list of assemblies | the assemblies and every part their kits add, at every depth: each part has a `path` and a `name` (the path joined by `-`) |
        | `settings-typed` | `errors` at a member | every interface setting is set and has its type |

        The batteries of `yen.lib.batteries.vars`:

        | Battery | Value of | Does |
        |---|---|---|
        | `generators { machineOf; }` | `reduce` of the generators sink | shared generators once, the rest per machine; a missing dependency is an error |
        | `vars-plan { from; machines; recipientsOf; }` | `out` of the generators sink | per machine: secret files with their paths, recipients, generation order |
        | `secret-reads { from; reads; }` | `errors` | an eval-time read of a secret file |
        | `public-value { root; }` | a function | a public var read at eval time, with a default |

        Working kits that use these batteries: [Kits for services](/batteries/kits-services/), [Bundles](/batteries/kits-bundles/)
        and the templates [kits-base](https://github.com/vic/yen/tree/main/templates/kits-base) and
        [kits-homelab](https://github.com/vic/yen/tree/main/templates/kits-homelab).
      ''
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
      one-assembly-more = {
        t1 = yes (result.flake.config.web.verbose);
        t2 = yes (result.flake.config.nas.verbose);
      };
      settings-layers = {
        t1 = eq (result.flake.config.web.backup.daily.dir) ("/srv/backup");
        t2 = eq (result.flake.config.nas.backup.daily.dir) ("/var/backup");
      };
      exports = eq (result.flake.config.web.backup.daily.to) ([ "nas:22" ]);
      vars-plan = {
        t1 = eq (map (g: g.name) result.flake.varsPlan.web.order) ([
          "ssh"
          "borg-daily"
        ]);
        t2 = yes (
          builtins.elem "/run/secrets-for-users/vars/borg-daily/passphrase" (
            map (f: f.path) result.flake.varsPlan.web.files
          )
        );
      };
      public-value = {
        t1 = eq (result.flake.config.web.sshPub) ("ssh-ed25519 AAAAweb");
        t2 = eq (result.flake.config.nas.sshPub) ("absent");
      };
      contract = eq (map (e: e.error) (variant "variants/two-servers.nix").errors) ([
        "kits: assembly daily role server: 2 machines, at most 1"
      ]);
      by-name =
        let
          es = map (e: e.error) (variant "variants/by-name.nix").errors;
        in
        {
          t1 = yes (builtins.elem "kits: assembly hourly role server: `at` is a string, not a predicate" es);
          t2 = yes (builtins.any (e: builtins.match ".*kit.*string.*|.*string.*kit.*" e != null) es);
        };
    };
}
