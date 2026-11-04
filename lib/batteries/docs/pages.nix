#: lib.batteries.docs.pages :: { inputs; engine; read; } -> dir -> page -- a page directory as data: its meta, its eval result, its flake and what a change does
# The loader of a docs site. `dir` holds `page.nix` and, when the page has code, `modules/` (a fleet the page queries) and
# `flake.nix` (its template). `read` loads a Nix file (`import`), `engine` evaluates a module (`inputs.yen.lib`), and
# `inputs` needs `nixpkgs` and `import-tree`. The page has `page`, `result` (null without `modules/`), `variant`, `only`,
# `flake`, `template` and `inputsKnown`.
#   x = docs.pages { inherit inputs engine; read = import; } ./pages/why;  x.result.errors
_:
{
  inputs,
  engine,
  read,
}:
dir:
let
  b = builtins;
  has = f: b.pathExists (dir + "/${f}");
  flakeNix = read (dir + "/flake.nix");
  module = {
    imports = [ (inputs.import-tree (dir + "/modules")) ];
    inherit inputs;
    inherit (inputs.nixpkgs) lib;
    yen.sinks = {
      inputs = { };
      lib = { };
    };
  };
in
{
  inherit
    dir
    inputs
    module
    engine
    ;
  page = read (dir + "/page.nix");
  # the eval result: every query of the page's fleet
  result = if has "modules" then engine.eval module else null;
  # the page with one more file (a `variants/` file, outside `modules/`): what a change does
  variant =
    f:
    engine.eval {
      imports = [
        module
        (dir + "/${f}")
      ];
    };
  # only some files of the page: an early step of a migration
  only =
    fs:
    engine.eval {
      imports = map (f: dir + "/${f}") fs;
      inherit (module) inputs lib yen;
    };
  # the page's flake outputs, from its own flake.nix
  flake = if has "flake.nix" then flakeNix.outputs (inputs // { self = dir; }) else null;
  template = has "flake.nix";
  inputsKnown = !has "flake.nix" || b.all (n: inputs ? ${n}) (b.attrNames flakeNix.inputs);
}
