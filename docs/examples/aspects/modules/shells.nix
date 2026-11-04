{ yen, ... }:
{
  # active at hosts and at users; static content lands once at each receiver
  yen.aspects.zsh = {
    # (1)
    at = [
      yen.kinds.host
      yen.kinds.user
    ];
    packages = "zsh"; # (2)
  };
  # content that names the scope lands once per scope
  yen.aspects.dotfiles = {
    at = yen.kinds.user;
    packages = { user, ... }: "dotfiles-${user.name}"; # (3)
  };
}
