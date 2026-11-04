# A home-manager module reads its host and its user as args: no extraSpecialArgs, no osConfig.
{ yen, ... }:
{
  yen.aspects.prompt = {
    at = yen.lib.all [
      yen.kinds.user
      (yen.lib.within yen.kinds.host) # (1)
    ];
    homeManager =
      { host, user, ... }: # (2)
      {
        home.sessionVariables.PROMPT_TAG = "${user.name}@${host.name}";
      };
  };
}
