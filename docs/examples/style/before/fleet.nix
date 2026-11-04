# The same fleet, in the style to avoid: names as strings, spawns by hand, a nested `let`, `with`, and a predicate
# written by hand. It gives the same flake.
{ yen, lib, ... }:
{
  yen.kinds.fleet = {
    spawns.env = _: yen.env;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.env.spawns.host = s: lib.filterAttrs (_: h: h.env == s.name) yen.host;
  yen.kinds.host = {
    fields = {
      env = yen.lib.str;
      ports = yen.lib.opt (yen.lib.listOf yen.lib.port) [ ];
    };
    spawns.user = s: lib.filterAttrs (_: u: lib.elem s.name u.hosts) yen.user;
    sinks.nixos = {
      reduce = yen.lib.reduce.merge;
      out =
        { scope, sinks, ... }:
        {
          config.${scope.name} = sinks.nixos;
        };
    };
  };
  yen.kinds.user.fields.hosts = yen.lib.listOf yen.lib.str;

  yen.aspects.firewall = {
    at = yen.kinds.host;
    nixos =
      { host, ... }:
      let
        ports = host.ports;
      in
      {
        networking.firewall.allowedTCPPorts = ports;
      };
  };
  yen.aspects.ssh = {
    at = yen.lib.all [
      (
        s:
        let
          envOf =
            x:
            if x.parent == null then
              null
            else if x.parent.kind == "env" then
              x.parent.name
            else
              envOf x.parent;
        in
        envOf s == "prod"
      )
      (yen.lib.below yen.kinds.user)
    ];
    nixos.services.openssh.enable = true;
  };
  yen.aspects.peers = {
    at = yen.kinds.host;
    cycle =
      { tree, scope, ... }:
      let
        hosts.instances = yen.kinds.host;
      in
      {
        tree = [ hosts ];
        nixos = [
          {
            networking.hosts."10.0.0.1" =
              with builtins;
              map (p: p.name) (filter (p: p.name != scope.name && p.env == scope.env) (tree.select hosts));
          }
        ];
      };
  };

  yen.fleet.main = { };
  yen.env = {
    prod = { };
    lab = { };
  };
  yen.host = {
    web = {
      env = "prod";
      ports = [ 443 ];
    };
    db = {
      env = "prod";
      ports = [ 5432 ];
    };
    box.env = "lab";
  };
  yen.user.ana.hosts = [
    "web"
    "box"
  ];
  yen.flake = { out, ... }: out;
}
