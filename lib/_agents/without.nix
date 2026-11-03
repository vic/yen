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
    let
      mk = fs: args // { imports = fs; };
      hit = (eval (mk files)).declaredIn path;
      keep = filter (f: !elem (toString f) hit) files;
    in
    {
      dropped = filter (f: elem (toString f) hit) files;
      result = eval (mk keep);
    };
in
{
  inherit
    without
    ;
}
