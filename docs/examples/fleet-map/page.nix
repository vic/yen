{
  title = "The reference fleet";
  description = "Every module of the reference fleet, Yen's running specification, and what each one shows.";
  section = "reference";
  order = 4;

  body =
    { docs, inputs, ... }:
    let
      root = inputs.yen + "/reference/modules";
      repo = "https://github.com/vic/yen/blob/main/reference/modules";
      # the first comment line of a file: what it shows
      comment = f: builtins.match "# (.*)" (builtins.head (builtins.split "\n" (builtins.readFile f)));
      about = f: if comment f == null then "" else builtins.head (comment f);
      nixIn =
        d:
        builtins.filter (n: builtins.match "[^_].*\\.nix" n != null) (
          builtins.attrNames (builtins.readDir d)
        );
      dirs = builtins.filter (d: (builtins.readDir root).${d} == "directory") (
        builtins.attrNames (builtins.readDir root)
      );
      row = d: n: [
        "[`${d}/${n}`](${repo}/${d}/${n})"
        (builtins.replaceStrings [ "|" ] [ "\\|" ] (about (root + "/${d}/${n}")))
      ];
    in
    [
      ''
        [`reference`](https://github.com/vic/yen/tree/main/reference) is a complete, running specification of Yen. It
        models everything [Den](/migrate/from-den/), den-hoag and clan can do, plus the advanced cases of several real
        fleets, and each pattern has a check. It is big on purpose: read these docs first, then come here to see how a
        pattern looks at scale.

        This index is built from the fleet's own files. Each row is a [module](/principles/modules/) and its first comment line.
      ''
      (docs.sh ''
        git clone https://github.com/vic/yen && cd yen/reference
        nix eval --impure --file tests.nix failed   # [ ]: a check for each pattern
      '')
    ]
    ++ map (
      d: "## ${d}\n\n" + docs.table [ "Module" "What it shows" ] (map (row d) (nixIn (root + "/${d}")))
    ) dirs;

  checks =
    {
      inputs,
      eq,
      yes,
      no,
      ...
    }:
    {
      has-modules = yes (builtins.pathExists (inputs.yen + "/reference/modules/topology/fleet.nix"));
    };
}
