# A role is an aspect whose `at` is a fact test. Roles build on roles.
{ yen, lib, ... }:
let
  inherit (yen.lib) all not;
in
{
  yen.aspects = {
    server.at = s: (s.form or null) == "server"; # (1)
    workstation.at =
      s:
      lib.elem (s.form or null) [
        "laptop"
        "desktop"
      ];
    laptop.at = s: (s.form or null) == "laptop";
    nvidia.at = s: (s.gpu or null) == "nvidia";
    ci-runner.at = s: lib.elem "ci-runner" (s.labels or [ ]);
    gaming.at = all [
      # (2)
      yen.aspects.workstation
      yen.aspects.nvidia
      (not yen.aspects.laptop)
    ];
    backups.at = [
      # (3)
      yen.aspects.server
      yen.aspects.workstation
    ];
  };
}
