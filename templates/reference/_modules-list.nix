# The files of ./modules as a list, the way import-tree finds them (skip `_` paths, keep `*.nix`). For the permutation test.
let
  walk =
    dir:
    builtins.concatLists (
      map (
        n:
        let
          t = (builtins.readDir dir).${n};
          p = dir + "/${n}";
        in
        if builtins.substring 0 1 n == "_" then
          [ ]
        else if t == "directory" then
          walk p
        else if builtins.match ".*\\.nix" n != null then
          [ p ]
        else
          [ ]
      ) (builtins.attrNames (builtins.readDir dir))
    );
in
walk ./modules
