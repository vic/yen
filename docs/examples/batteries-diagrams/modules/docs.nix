# Docs that follow the fleet: a kinds table, links to the line that defines a thing, a doc line for every kind.
{ yen, ... }:
let
  inherit (yen.lib.batteries) docs;
  whole.graph = true; # a tree request: the whole fleet
  # the tables of a fleet: `fleet` is the whole fleet, with its data, that the tree request selects
  tablesOf = fleet: {
    kinds = docs.kinds fleet.kinds fleet.lib.graph; # (1)
    # any table: the hosts and their environment
    hosts = docs.table [ "Host" "Environment" ] (
      map (h: [
        h
        fleet.host.${h}.environment.name
      ]) (builtins.attrNames fleet.host)
    );
  };
in
{
  yen.kinds.fleet.sinks.links = {
    reduce = docs.links { root = ./.; }; # (2)
    out =
      { sinks, ... }:
      {
        links = sinks.links;
      };
  };
  yen.aspects.docs = {
    at = yen.fleet.main;
    links = {
      name = "db-field";
      file = "fleet.nix";
      needle = "db = maybe"; # (3)
      text = "db";
    };
    cycle =
      { tree, ... }:
      {
        tree = [ whole ];
        out = [ (tablesOf (tree.select whole)) ];
      };
    # flake templates from the directories under templates/ that have a flake.nix
    out.templates = builtins.mapAttrs (_: t: t.description) (
      docs.templates {
        root = ../templates;
        description = d: (import (d + "/flake.nix")).description;
      }
    );
    # a kind with no line here, or a line for a kind that is gone, is an error
    errors = docs.vocabulary {
      # (4)
      what = "kinds";
      names = builtins.attrNames yen.kinds;
      lines = {
        fleet = "the root";
        environment = "where hosts run";
        host = "a NixOS machine";
      };
    };
  };
}
