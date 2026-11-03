#: lib.batteries.kits.assemblies :: [ assembly ] -> [ assembly ] -- the assemblies, and every part their kits add, at every depth
# A kit's `adds` gives the parts of an assembly, keyed by a short name: `{ disko = { kit; roles; }; }`. A part lives
# under its assembly: its `path` is the assembly's path and the key. Its `name` is that path joined by `-`, an
# identifier for interface, generator and file names; `kits.contract` refuses two assemblies with one name.
#   assemblies = kits.assemblies (lib.attrValues yen.assembly);
_: own:
let
  b = builtins;
  pathOf = a: a.path or [ a.name ];
  partsOf =
    a:
    b.concatMap (
      key:
      let
        p = ((a.kit.adds or (_: { })) a).${key} // {
          kind = "assembly";
          path = pathOf a ++ [ key ];
          name = b.concatStringsSep "-" (pathOf a ++ [ key ]); # an identifier: interface, generator and file names use it
        };
      in
      [ p ] ++ partsOf p
    ) (b.attrNames ((a.kit.adds or (_: { })) a));
in
b.concatMap (a: [ a ] ++ partsOf a) own
