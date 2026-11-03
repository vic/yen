# The users of a host are written inside that host. Two hosts can have a user with the same name.
{ yen, ... }:
{
  yen.host.laptop = {
    addr = "10.0.0.1";
    user.vic.shell = "fish";
    user.ann.shell = "bash";
  };
  yen.host.server = {
    addr = "10.0.0.2";
    user.vic.shell = "zsh";
  };
}
