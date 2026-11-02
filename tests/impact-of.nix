# impactOf oracles: tests.impact-of.<test> = { expr; expected; }
self:
let
  impactOf = self._impact.impactOf;
  eq = expr: expected: { inherit expr expected; };
  d = id: { data = id; };
  k = sink: at: { inherit sink at; };
  chain = [
    {
      out = k "s" "B";
      reads = [ (d "A") ];
    }
    {
      out = k "t" "C";
      reads = [ (k "s" "B") ];
    }
  ];
in
{
  # P1: a dirty token dirties every edge that reads it, transitively
  chain =
    eq
      (impactOf {
        edges = chain;
        seeds = [ (d "A") ];
      })
      ([
        (k "s" "B")
        (k "t" "C")
        (d "A")
      ]);
  # negative control: nothing reads Z, so B and C stay clean
  unread = eq (impactOf {
    edges = chain;
    seeds = [ (d "Z") ];
  }) ([ (d "Z") ]);
  # a self-loop terminates
  loop = eq (impactOf {
    edges = [
      {
        out = k "s" "B";
        reads = [ (k "s" "B") ];
      }
    ];
    seeds = [ (k "s" "B") ];
  }) ([ (k "s" "B") ]);
  # a whole-fleet reader is dirty when anything is, and only then
  whole =
    eq
      (impactOf {
        edges = [ ];
        whole = [ (k "docs" "F") ];
        seeds = [ (d "A") ];
      })
      ([
        (k "docs" "F")
        (d "A")
      ]);
  whole-control = eq (impactOf {
    edges = [ ];
    whole = [ (k "docs" "F") ];
    seeds = [ ];
  }) ([ ]);
  # scope ids hold `:`, `/` and `@`: a token is data, never parsed
  ids =
    eq
      (impactOf {
        edges = [
          {
            out = k "out" "fleet:main";
            reads = [ (d "fleet:main/host:db@x") ];
          }
        ];
        seeds = [ (d "fleet:main/host:db@x") ];
      })
      ([
        (k "out" "fleet:main")
        (d "fleet:main/host:db@x")
      ]);
}
