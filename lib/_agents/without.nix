self:
let
  inherit (self._prelude) elem filter;
  inherit (self._engine) eval;
  # without: the fleet with the files that declare `path` removed (coarse: a whole file goes; no engine hook)
  #: lib.without :: { files; path; args ? { }; } -> { dropped; result; } -- the fleet without the files that declare path; args = sinks the root gives
  without =
    {
      files,
      path,
      args ? { },
    }:
    withoutHit files args ((eval (withFiles args files)).declaredIn path);
  withFiles = args: fs: args // { imports = fs; };
  # hit: the files that declare the path
  withoutHit = files: args: hit: {
    dropped = filter (f: elem (toString f) hit) files;
    result = eval (withFiles args (filter (f: !elem (toString f) hit) files));
  };
in
{
  inherit
    without
    ;
}
