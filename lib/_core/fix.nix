# The fixpoint of f: the value x with x = f x. Laziness lets f read the parts of x that it gives.
_: f:
let
  x = f x;
in
x
