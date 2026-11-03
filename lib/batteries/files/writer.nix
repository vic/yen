#: lib.batteries.files.writer :: { from; files; lib; pkgs; root; relativeRoot ? ; unchecked ? ; } -> out value -- packages.<system>.write-files and one check per repo file
# Repo files with github:sini/files: the modules of a sink become `packages.<system>.write-files` and one check per file
# (the committed file must match). The value of the sink's `out` key. `unchecked` names the files that are written but
# not committed (a build output, such as generated docs pages): they get no check.
#   yen.kinds.repo.sinks.files.out = yen.lib.batteries.files.writer {
#     from = yen.kinds.repo.sinks.files; inherit (inputs) files; inherit lib pkgs; root = inputs.self; };
self:
let
  inherit (self.batteries) eval-modules;
in
{
  from,
  files,
  lib,
  pkgs,
  root,
  relativeRoot ? null,
  unchecked ? _: false,
}:
eval-modules {
  inherit from lib;
  modules = [
    files.module
    {
      _module.args.pkgs = pkgs;
      files = {
        inherit root;
      }
      // (if relativeRoot == null then { } else { inherit relativeRoot; });
    }
  ];
  result = e: {
    packages.${pkgs.stdenv.hostPlatform.system}.write-files = e.config.files.writer.drv;
    checks.${pkgs.stdenv.hostPlatform.system} = lib.filterAttrs (
      n: _: !(unchecked (lib.removePrefix "files/" n))
    ) e.config.files.checks;
  };
}
