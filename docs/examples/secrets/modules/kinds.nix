# A secret is data: nothing spawns it. A host's `secrets` sink only takes secret refs.
{ yen, lib, ... }:
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.secret.fields = {
    # (1)
    file = yen.lib.str; # the encrypted file in the repo
    owners = yen.lib.listOf yen.kinds.host;
  };
  yen.kinds.host.sinks.secrets = {
    # (2)
    reduce = yen.lib.reduce.set;
    of = yen.kinds.secret; # (3)
    # (4) the plan a secrets tool reads: agenix, sops-nix, or your own
    out =
      { host, secrets, ... }:
      {
        secretsPlan.${host.name} = map (s: {
          inherit (s) name file;
          path = "/run/secrets/${s.name}";
        }) secrets;
      };
  };

  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
}
