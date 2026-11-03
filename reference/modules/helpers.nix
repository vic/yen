# Shared values. `yen.helpers` is a query like any other declaration.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  inherit (yen.lib) same holds;
  # the posix groups gs meet the grants of scope s, and its gates when it has any
  allowedOn =
    s: gs:
    yen.helpers.meets gs (s.environment.grants ++ s.grants)
    && (s.gates == [ ] || yen.helpers.meets gs s.gates);
  guiIn = cfg: bad: lib.intersectLists bad (map lib.getName cfg.config.environment.systemPackages); # the bad packages cfg installs
in
{
  yen.helpers = {
    machines = [
      yen.kinds.host
      yen.kinds.guest
      yen.kinds.mac
    ];
    linux = [
      yen.kinds.host
      yen.kinds.guest
    ];
    pkgsOf = m: m.channel.nixpkgs.legacyPackages.${m.system.name};
    upTo = p: s: lib.findFirst (holds p) null (lib.reverseList s.up); # nearest ancestor-or-self where p holds
    # nested groups: every group that contains one of gs, transitively
    closure =
      groups: gs:
      map (x: x.g) (
        builtins.genericClosure {
          startSet = map (g: {
            key = g.name;
            inherit g;
          }) gs;
          operator =
            x:
            map (p: {
              key = p.name;
              g = p;
            }) (lib.filter (p: lib.any (same x.g) p.members) groups);
        }
      );
    # ACL: a posix group of the user meets the environment's or the machine's grants, and the machine's gates when it has any
    meets = xs: ys: lib.any (x: lib.any (same x) ys) xs;
    posixOf =
      u: lib.filter (g: g.label == "posix") (yen.helpers.closure (lib.attrValues yen.group) u.groups);
    usersOn = s: lib.filterAttrs (_: u: allowedOn s (yen.helpers.posixOf u)) yen.user;
    flatten = a: ms: lib.mkMerge (map (m: if lib.isFunction m then m a else m) ms); # config-only submodules (users.users.<n>)
    noGui =
      system: h: cfg: bad:
      inputs.nixpkgs.legacyPackages.${system.name}.runCommand "${h}-no-gui" { } (
        if guiIn cfg bad == [ ] then
          "touch $out"
        else
          "echo 'gui on ${h}: ${toString (guiIn cfg bad)}'; exit 1"
      );
    mermaid =
      g: yen.lib.batteries.mermaid.flowchart { direction = "TD"; } (yen.lib.batteries.mermaid.routes g);
    ids =
      fleet:
      lib.listToAttrs (
        lib.imap0 (i: n: lib.nameValuePair n i) (
          lib.sort (a: b: a < b) (
            map (s: s.name) (lib.filter (s: fleet.lib.holds fleet.kinds.host s) fleet.lib.graph.scopes)
          )
        )
      ); # deterministic: sorted host scope names
  };
}
