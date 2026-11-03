self:
let
  b = builtins;
  inherit (self._krn.core)
    answer
    answerC
    start
    take
    takeAll
    takeFuel
    ;
  #: lib.krn.run :: n -> (q -> goal) -> [ answer ] -- the first n answers for q
  run = n: f: map answer (take n (start f));
  #: lib.krn.runAll :: (q -> goal) -> [ answer ] -- every answer for q (finite searches only)
  runAll = f: map answer (takeAll (start f)); # finite searches only
  # fuel-bounded search: { answers; complete; }. complete = false: fuel ran out first, answers are what was found.
  #: lib.krn.runFuel :: n -> fuel -> (q -> goal) -> { answers; complete; } -- up to n answers in fuel steps; complete is false when the fuel ran out
  runFuel =
    n: fuel: f:
    let
      r = takeFuel n fuel (start f);
    in
    r // { answers = map answer r.answers; };
  #: lib.krn.runAllFuel :: fuel -> (q -> goal) -> { answers; complete; } -- every answer found in fuel steps
  runAllFuel = runFuel (-1);
  # maximize fuel measure f: { best; value; complete; count; }. best = first answer with the largest measure
  # (null if none). Under complete = false, best is "best found", not proven optimal.
  #: lib.krn.maximize :: fuel -> (answer -> int) -> (q -> goal) -> { best; value; complete; count; } -- the first answer with the largest measure (best found when not complete)
  maximize =
    fuel: measure: f:
    let
      r = runAllFuel fuel f;
      pick =
        acc: a:
        let
          m = measure a;
        in
        if acc == null || m > acc.value then
          {
            best = a;
            value = m;
          }
        else
          acc;
      top = b.foldl' pick null r.answers;
    in
    {
      best = if top == null then null else top.best;
      value = if top == null then null else top.value;
      inherit (r) complete;
      count = b.length r.answers;
    };
  # with the constraints left on the answer: { value; neq; dom; }
  #: lib.krn.runC :: n -> (q -> goal) -> [ { value; neq; dom; } ] -- the first n answers with the constraints left on them
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
