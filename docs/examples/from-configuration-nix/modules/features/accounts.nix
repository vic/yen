# Each user gives its account. A user has no `nixos` sink, so the account goes up to the host.
{ yen, ... }:
{
  yen.aspects.account = {
    at = yen.kinds.user; # (1)
    nixos =
      { user, ... }: # (2)
      {
        users.users.${user.name} = {
          isNormalUser = true;
          extraGroups = user.groups;
        };
      };
  };
}
