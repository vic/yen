# Stored queries, labels and valid time for agents.
# - `yen.queries.<name> = { params; answer; }`: named questions with typed parameters; an agent lists them (`queries`)
#   and calls `ask name args`; a fleet name is a ref (from JSON: { kind; name; }).
# - `yen.labels`: trust by file path prefix. Content declared under modules/agent/ is trust 1 (written by agents),
#   the rest trust 3. `floor 3` lists every routed element an agent-written aspect gives.
# - valid time: a machine can have `validTo`; `retire-notice` marks machines past it at the fleet's review date.
{ yen, lib, ... }:
let
  scopeOf = host: result: lib.findFirst (yen.lib.same host) null result.scopes;
  # the machines of an assembly that take a role, as refs
  machinesIn =
    assembly: result: rl:
    lib.unique (
      map (s: { inherit (s.parent) kind name; }) (
        lib.filter (
          s: yen.lib.holds yen.kinds.member s && yen.lib.same s.assembly assembly && s.role == rl
        ) result.scopes
      )
    );
  # each client waits for every server
  installGraph =
    servers: clients:
    yen.lib.graphs.of (clients ++ servers) (
      m: if lib.any (yen.lib.same m) servers then [ ] else servers
    );
in
{
  yen.queries = {
    hostsIn = {
      params.env = yen.kinds.environment;
      answer =
        { env, result }:
        map (s: s.name) (
          lib.filter (yen.lib.holds (
            yen.lib.all [
              yen.kinds.host
              (yen.lib.within env)
            ]
          )) result.scopes
        );
    };
    aspectsOn = {
      params.host = yen.kinds.host;
      answer =
        { host, result }:
        if scopeOf host result == null then
          [ ]
        else
          lib.filter (n: result.active.${n}.${(scopeOf host result).id}) (lib.attrNames result.active);
    };
    errorsBy = {
      params.code = yen.lib.maybe (yen.lib.is builtins.isString); # an error code is data, not a fleet name
      answer = { code, result }: lib.filter (e: code == null || e.code == code) result.errors;
    };
    # install order: in an assembly, each client machine waits for the servers (yen.lib.graphs.layers)
    installOrder = {
      params.assembly = yen.kinds.assembly;
      answer =
        { assembly, result }:
        map (map (m: m.name)) (
          yen.lib.graphs.layers (
            installGraph (machinesIn assembly result "server") (machinesIn assembly result "client")
          )
        );
    };
  };
  yen.labels = {
    "modules/" = {
      trust = 3;
    };
    "agent/" = {
      trust = 1;
    };
  };

  yen.kinds.machine.fields.validTo = yen.lib.opt (yen.lib.listOf yen.lib.str) [ ];
  yen.host.web-2.validTo = [ "2026-11-01" ];
  yen.aspects.retire-notice = {
    at = yen.lib.all [
      yen.kinds.host
      (s: s.validTo != [ ])
      (yen.lib.not (s: yen.lib.validAt "2026-11-15" (s // { validTo = lib.head s.validTo; })))
    ];
    nixos.environment.etc."yen/retired".text = "past validTo at the review date 2026-11-15";
  };
}
