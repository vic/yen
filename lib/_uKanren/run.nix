self:
let
  b = builtins;
  inherit (self._uKanren.core)
    answer
    answerC
    start
    take
    takeAll
    takeFuel
    ;
  #: lib.uKanren.run :: n -> (q -> goal) -> [ answer ] -- the first n answers for q; `{ x, y, … }: goal` names the query variables and each answer is { x; y; }
  run = n: f: map answer (take n (start f));
  #: lib.uKanren.runAll :: (q -> goal) -> [ answer ] -- every answer for q (finite searches only)
  runAll = f: map answer (takeAll (start f)); # finite searches only
  # fuel-bounded search: { answers; complete; }. complete = false: fuel ran out first, answers are what was found.
  #: lib.uKanren.runFuel :: n -> fuel -> (q -> goal) -> { answers; complete; } -- up to n answers in fuel steps; complete is false when the fuel ran out
  runFuel =
    n: fuel: f:
    fuelAnswers (takeFuel n fuel (start f));
  fuelAnswers = r: r // { answers = map answer r.answers; };
  #: lib.uKanren.runAllFuel :: fuel -> (q -> goal) -> { answers; complete; } -- every answer found in fuel steps
  runAllFuel = runFuel (-1);
  # maximize fuel measure f: { best; value; complete; count; }. best = first answer with the largest measure
  # (null if none). Under complete = false, best is "best found", not proven optimal.
  #: lib.uKanren.maximize :: fuel -> (answer -> int) -> (q -> goal) -> { best; value; complete; count; } -- the first answer with the largest measure (best found when not complete)
  maximize =
    fuel: measure: f:
    maxIn measure (runAllFuel fuel f);
  maxIn = measure: r: maxOf r (b.foldl' (pickBy measure) null r.answers);
  # the best so far: the first answer whose measure is larger than every one before it
  pickBy =
    measure: acc: a:
    pickWith acc a (measure a);
  pickWith =
    acc: a: m:
    if acc == null || m > acc.value then
      {
        best = a;
        value = m;
      }
    else
      acc;
  maxOf = r: top: {
    best = if top == null then null else top.best;
    value = if top == null then null else top.value;
    inherit (r) complete;
    count = b.length r.answers;
  };
  # with the constraints left on the answer: { value; neq; dom; }
  #: lib.uKanren.runC :: n -> (q -> goal) -> [ { value; neq; dom; } ] -- the first n answers with the constraints left on them
  runC = n: f: map answerC (take n (start f));

in
{
  inherit
    run
    runAll
    runFuel
    runAllFuel
    maximize
    runC
    ;
}
