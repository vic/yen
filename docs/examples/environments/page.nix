{
  title = "Environments";
  description = "prod and staging: hosts grouped by where they run, settings that cascade, and access from groups.";
  section = "recipes";
  order = 3;

  body =
    { docs, result, ... }:
    [
      ''
        An environment owns its hosts. It gives them a domain and default settings, and it decides which people
        may log in. staging inherits from prod what it does not set. These are the [kinds](/model/kinds-fields/):
      ''
      (docs.fileNoted "{22,27}" "modules/kinds.nix")
      ''
        At `(1)`, `group` is a kind with no fields. At `(2)`, an environment may have a `base` environment. At `(3)`, `grants`
        lists the groups that may log in. At `(4)`, `spawns.host` makes each host a [scope](/model/scopes/) under the environment
        that it points to. At `(5)`, `spawns.user` makes a user a scope under a host when one of the user's groups is in the grants.

        This is the data:
      ''
      (docs.fileNoted "" "modules/data.nix")
      ''
        At `(1)`, `prod` grants `admins`. At `(2)`, `staging` takes `prod` as its base. At `(3)`, `web-next` sets its own time zone.
        Users are not listed per host. A user lives on a host when one of their groups is in the environment's `grants`:
      ''
      (docs.scopes result)
      ''
        ## Settings cascade

        `yen.lib.cascade` takes the first value along host, environment, base environment. This [aspect](/behavior/aspects/) uses it:
      ''
      (docs.fileNoted "{6-10}" "modules/base.nix")
      ''
        At `(1)`, the cascade lists the host, its environment and the base of the environment. At `(2)`, the time zone of
        the host comes from it. At `(3)`, the key `out` sends the time zone up to the fleet. At `(4)`, the aspect `account` is
        active at users. The time zones:
      ''
      (docs.value result.flake.timeZones)
      (docs.tip "Promote a host" ''
        Move `web-next` to prod with one edit: `environment = yen.environment.prod`. Its domain, its time zone default
        and its users follow from the data.
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
