{
  title = "Environments";
  description = "prod and staging: hosts grouped by where they run, settings that cascade, and access from groups.";
  section = "recipes";
  order = 3;

  body =
    { docs, result, ... }:
    [
      ''
        An environment owns its hosts. It gives them a domain and default settings, and decides who may log in.
        Whatever staging doesn't set, it inherits from prod. The [kinds](/model/kinds-fields/):
      ''
      (docs.fileNoted "{22,27}" "modules/kinds.nix")
      ''
        At `(1)`, `group` is a kind with no fields. At `(2)`, an environment may have a `base` environment, and at `(3)`,
        `grants` lists the groups that may log in. At `(4)`, `spawns.host` makes each host a [scope](/model/scopes/) under
        the environment it points to. At `(5)`, `spawns.user` puts a user under a host when one of the user's groups is in
        the grants.

        The data:
      ''
      (docs.fileNoted "" "modules/data.nix")
      ''
        At `(1)`, `prod` grants `admins`. At `(2)`, `staging` takes `prod` as its base, and at `(3)`, `web-next` sets its
        own time zone. Nobody lists users per host: a user lives on a host when one of their groups is in the
        environment's `grants`:
      ''
      (docs.scopes result)
      ''
        ## Settings cascade

        `yen.lib.cascade` takes the first value it finds along host, environment and base environment. This
        [aspect](/behavior/aspects/) uses it:
      ''
      (docs.fileNoted "{6-10}" "modules/base.nix")
      ''
        At `(1)`, the cascade lists the host, its environment and that environment's base, and at `(2)`, the host's time
        zone comes from it. At `(3)`, the `out` key sends the time zone up to the fleet. At `(4)`, the `account` aspect is
        active at users. The time zones:
      ''
      (docs.value result.flake.timeZones)
      (docs.tip "Promote a host" ''
        Moving `web-next` to prod is one edit: `environment = yen.environment.prod`. Its domain, default time zone and
        users all follow from the data.
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
      zones = eq (result.flake.timeZones) ({
        api-next = "UTC";
        web = "UTC";
        web-next = "Europe/Berlin";
      });
      access = eq (builtins.length (builtins.filter (s: s.name == "dev") result.scopes)) (2);
    };
  e2e =
    {
      flake,
      eq,
      yes,
      no,
      ...
    }:
    {
      domain = eq (flake.nixosConfigurations.api-next.config.networking.fqdn) (
        "api-next.staging.example.com"
      );
      tz = eq (flake.nixosConfigurations.api-next.config.time.timeZone) ("UTC");
    };
}
