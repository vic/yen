{
  title = "Knowledge packs";
  description = "The fleet as sorted N-Triples with a sha256, and SHACL shapes from the schema, for graph stores.";
  section = "agents";
  order = 4;

  body =
    {
      docs,
      result,
      engine,
      ...
    }:
    let
      pack = engine.rdf.share result;
    in
    [
      ''
        An [agent](/agents/agent-surface/) with a knowledge store (a triple store like quipu) can keep the fleet as a
        graph and query it with SPARQL. The fleet gives itself as sorted N-Triples: [scopes](/model/scopes/),
        [kinds](/model/kinds-fields/), parents, active [aspects](/behavior/aspects/), every routed element as a node with
        its origin, and errors. The pack adds a sha256 and a count. This fleet has one environment and two hosts
        ([working example](https://github.com/vic/yen/tree/main/docs/examples/knowledge)):
      ''
      (docs.file "modules/hosts.nix")
      ''
        Here are the first triples of its pack, with the count and the sha256:
      ''
      (docs.code "text" (
        builtins.concatStringsSep "\n" (
          builtins.genList (
            i: builtins.elemAt (builtins.filter builtins.isString (builtins.split "\n" pack.ntriples)) i
          ) 12
        )
        + "\n…"
      ))
      (docs.value { inherit (pack) count sha256; })
      ''
        ## Same fleet, same hash

        The triples are sorted, and Yen gives the same answer whatever the file order, so you can compare two revisions by
        hash first. The docs check this: this template's files, loaded in reverse order, give the same sha256.

        A fleet can give its pack as a flake output:
      ''
      (docs.fileNoted "" "modules/pack.nix")
      ''
        `(1)` is a [tree request](/behavior/cycle/) for the whole fleet, and `(2)` is an aspect at the root kind, in a
        cycle. `(3)` calls `yen.lib.rdf.share`, which turns the eval result into a pack. The output drops the triples and
        keeps the hash and the count.

        ## Shapes

        `yen.lib.rdf.shacl result` gives SHACL shapes from the schema: one node shape for each kind with scopes,
        `yen:name` required, `yen:parent` of the spawning kind, each field at most once, and `sh:class` for ref fields.
      ''
      (docs.code "turtle" (builtins.substring 0 640 (engine.rdf.shacl result) + "…"))
      (docs.tip "One snapshot per revision" ''
        Store each revision's pack under one snapshot key, replacing the previous one. The store keeps old ones readable
        by transaction, so "what did the fleet look like before this change?" is just a query.
      '')
    ];

  checks =
    {
      result,
      engine,
      only,
      eq,
      yes,
      no,
      ...
    }:
    {
      stable = eq ((engine.rdf.share result).sha256) (
        (engine.rdf.share (only [
          "modules/pack.nix"
          "modules/hosts.nix"
          "modules/fleet.nix"
        ])).sha256
      );
      shapes = yes (builtins.isString (engine.rdf.shacl result));
    };
}
