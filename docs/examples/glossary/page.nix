{
  title = "Glossary";
  description = "Each yen word, in one line, with the page that explains it.";
  section = "reference";
  order = 1;

  body =
    { docs, ... }:
    [
      (docs.table
        [ "Word" "Meaning" "Page" ]
        [
          [
            "kind"
            "a type of thing, with fields, [spawns](/model/scopes/) and [sinks](/behavior/sinks/)"
            "[Kinds and fields](/model/kinds-fields/)"
          ]
          [
            "instance"
            "`yen.<kind>.<name>`: one thing of a kind"
            "[Kinds and fields](/model/kinds-fields/)"
          ]
          [
            "field"
            "a typed datum of each instance"
            "[Types and defaults](/model/types/)"
          ]
          [
            "type"
            "any value with `check = value: bool`; a composite also gives `parse`: its shape now, its parts later"
            "[Types and defaults](/model/types/)"
          ]
          [
            "ref"
            "a field value that is another instance"
            "[Instances and refs](/model/instances-refs/)"
          ]
          [
            "data kind"
            "a kind that no kind spawns: instances with no [scope](/model/scopes/)"
            "[Instances and refs](/model/instances-refs/#data-kinds)"
          ]
          [
            "root kind"
            "the kind that nothing spawns, and that spawns others"
            "[Scopes and spawns](/model/scopes/)"
          ]
          [
            "scope"
            "one instance at one place in the tree; its id is its path"
            "[Scopes and spawns](/model/scopes/)"
          ]
          [
            "spawns"
            "a function from a parent scope to the instances under it"
            "[Scopes and spawns](/model/scopes/)"
          ]
          [
            "aspect"
            "behavior: active where `at` holds, gives elements by key"
            "[Aspects](/behavior/aspects/)"
          ]
          [
            "predicate"
            "a function of a scope, or a kind, instance, aspect or list"
            "[Predicates](/behavior/predicates/)"
          ]
          [
            "element"
            "one value an aspect gives to a sink"
            "[Aspects](/behavior/aspects/)"
          ]
          [
            "sink"
            "collects elements at a receiver and reduces them"
            "[Sinks and reduce](/behavior/sinks/)"
          ]
          [
            "receiver"
            "the nearest ancestor-or-self scope with the sink, where its `at` holds"
            "[Routing and walls](/behavior/routing/)"
          ]
          [
            "wall"
            "a sink with no keys: elements stop there"
            "[Routing and walls](/behavior/routing/#walls)"
          ]
          [
            "forward"
            "a sink key that names another sink and feeds it"
            "[Forwards](/behavior/forwards/)"
          ]
          [
            "arg"
            "a named arg of an element: a kind, a sink, `scope`, or open"
            "[Args](/behavior/args/)"
          ]
          [
            "component"
            "an aspect's `cycle`: [sources](/behavior/cycle/) in, sinks out, 0 to n elements"
            "[The cycle form](/behavior/cycle/)"
          ]
          [
            "error record"
            "an error as data, with `code`, `fix` and `class`"
            "[Errors as data](/principles/errors/)"
          ]
          [
            "query"
            "an answer of `eval`: errors, graph, active, reduced, …"
            "[Queries](/query/queries/)"
          ]
          [
            "invariant"
            "Datalog rules over the facts, as data; a true `[ \"bad\" … ]` atom is a violation"
            "[Invariants](/query/invariants/)"
          ]
          [
            "stored query"
            "a named question, asked with `result.ask`"
            "[Stored queries](/query/stored-queries/)"
          ]
          [
            "stage"
            "the fleet without and with a change, compared"
            "[Stage a change](/agents/stage/)"
          ]
          [
            "grant"
            "where a change may reach; grants only narrow"
            "[Stage a change](/agents/stage/#grants-only-narrow)"
          ]
          [
            "change program"
            "a change as data ops: set, ref, place, new"
            "[Change programs](/agents/programs/)"
          ]
          [
            "knowledge pack"
            "the fleet as sorted N-Triples with a sha256"
            "[Knowledge packs](/agents/knowledge/)"
          ]
          [
            "nested kind"
            "a kind declared in a kind, `kinds.<c>`; its instances live under the parent"
            "[Nested kinds](/model/nested-kinds/)"
          ]
          [
            "owned aspect"
            "an aspect in a kind (`aspects.<a>`, on that kind by default) or in an instance; named by its declaration path"
            "[Aspects](/behavior/aspects/#aspects-a-kind-or-an-instance-owns)"
          ]
          [
            "deep check"
            "`result.deep`: the parts of typed values (list elements, attrset values) checked after evaluation"
            "[Types and defaults](/model/types/)"
          ]
          [
            "certificate"
            "the steps that prove a verdict; a small checker in Nix and a checker proved in Lean accept it"
            "[Verified by Lean](/query/lean/)"
          ]
          [
            "battery"
            "a ready value for one key of your fleet: `yen.lib.batteries`"
            "[Battery packs](/batteries/)"
          ]
          [
            "kit, assembly, member"
            "a kit is a reusable part with roles; an assembly is one use of it; a member is one machine in one role"
            "[Kits](/batteries/kits/)"
          ]
          [
            "module sink"
            "a top-level key of a module that any module reads as an arg; `yen.sinks` declares it"
            "[Modules](/principles/modules/)"
          ]
        ]
      )
    ];
}
