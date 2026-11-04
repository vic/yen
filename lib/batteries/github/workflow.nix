#: lib.batteries.github.workflow :: { from; path; doc; header ? ; } -> key value -- a workflow file from the jobs of sink from
# a workflow file from the jobs of sink `from` (reduce merge: one attr per job). `header` reads the job names.
#   yen.kinds.repo.sinks.jobs = { reduce = yen.lib.reduce.merge;
#     files = github.workflow { from = yen.kinds.repo.sinks.jobs; path = ".github/workflows/test.yml";
#       doc = { name = "test"; on.push = { }; }; }; };
self:
let
  inherit (self.batteries.github) yaml;
  textOf =
    header: doc: jobs:
    header (builtins.attrNames jobs) + yaml (doc // { inherit jobs; });
in
{
  from,
  path,
  doc,
  header ? _: "",
}:
{ sinks, ... }:
{
  files.file.${path}.text = textOf header doc sinks.${from.__sink};
}
