{
  title = "Scopes and spawns";
  description = "A scope is one instance at one place in a tree. `spawns` builds the tree from your data.";
  section = "model";
  order = 4;

  body =
    { docs, result, ... }:
    [
      ''
        A scope is one instance at one place in the tree. A [kind](/model/kinds-fields/) says which instances live under
        it with `spawns.<kind>`. This file builds a tree of environments, hosts and users:
      ''
      (docs.fileNoted "" "modules/tree.nix")
      ''
        `spawns.<kind>` is a function of the parent scope. It gives the instances that live under it.
        `(1)` makes `fleet` spawn every environment. `fleet` is the root: no kind spawns it.
        `(2)` and `(3)` find the children by a ref field. `yen.lib.pointing "hosts" yen.user` gives the users whose
        `hosts` field holds the parent scope, as one ref or in a list.
        The root `fleet` has the instance `yen.fleet.main`, and this data fills the tree:
      ''
      (docs.fileNoted "" "modules/instances.nix")
      ''
        `(4)` gives one user two hosts, so that user gets two scopes.

        The tree comes from the data. Nothing lists the children by hand:
      ''
      (docs.scopes result)
      ''
        ## Identity is a path

        The id of a scope is its path: `fleet:main/environment:prod/host:web/user:alice`.
        One instance can live in several places. `alice` has two scopes, one under each of her hosts.
        Names need not be unique.

        `result.scopes` gives the scopes in order:
      ''
      (docs.value (map (s: s.id) result.scopes))
      ''
        ## Order

        A parent comes before its children. Siblings sort by the `order` sink (default `0`), then by name.
        This [aspect](/behavior/aspects/) gives the host `web` an `order` of `-1`:
      ''
      (docs.file "modules/order.nix")
      ''
        So `web` comes before `db`.
      ''
      (docs.aside "tip" "Kinds without scopes" ''
        A kind that no kind spawns is data: its instances have no scope, and refs to them still work.
        See [Instances and refs](/model/instances-refs/#data-kinds).
      '')
      ''
        ## Read the tree inside the fleet

        An aspect can read the tree. This example gives the scope ids as a flake output:
      ''
      (docs.fileNoted "" "modules/outputs.nix")
      ''
        `(1)` is a tree request: `graph = true` asks for the whole fleet. `(2)` reads the scopes of the answer.
        The [cycle](/behavior/cycle/) page explains tree requests.
      ''
    ];

  checks =
    {
      result,
      eq,
      yes,
      no,
      ...
    }:
    {
      alice-twice = eq (builtins.length (builtins.filter (s: s.name == "alice") result.scopes)) (2);
      web-before-db = eq (builtins.elemAt (map (s: s.name) result.scopes) 5) ("web");
      flake = eq (result.flake.scopes) (map (s: s.id) result.scopes);
    };
}
