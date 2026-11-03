{
  title = "The reference fleet";
  description = "Every module of reference, the running specification of yen, with what it shows.";
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
        [`reference`](https://github.com/vic/yen/tree/main/reference) is a complete running specification of yen.
        It models every capability of Den, den-hoag and clan, and the advanced cases of several real fleets. Each pattern has a check.
        It is big on purpose: read these docs first, then use the fleet to look up how a pattern looks at scale.

        This index is read from the fleet's files: each row is a [module](/principles/modules/) and its first comment line.
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
