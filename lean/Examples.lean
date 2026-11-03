import Wfm
import Facts
import Waves

/-!
The checker on a small program, with a mutant certificate for each condition it checks.
  0.   1 :- 0.   2 :- not 1.   3 :- not 3.   (4 has no rule)
Well-founded model: 0 and 1 true, 2 and 4 false, 3 undefined.
-/

open Yen

def r0 : Rule Nat := ⟨0, [], []⟩
def r1 : Rule Nat := ⟨1, [0], []⟩
def r2 : Rule Nat := ⟨2, [], [1]⟩
def r3 : Rule Nat := ⟨3, [], [3]⟩
def program : List (Rule Nat) := [r0, r1, r2, r3]

def good : Certificate Nat := ⟨[⟨0, 0, r0⟩, ⟨1, 1, r1⟩], [⟨2, 2⟩, ⟨4, 0⟩]⟩

example : check program good = true := by decide
-- proved at the stage of its premise, not after it
example : check program ⟨[⟨0, 0, r0⟩, ⟨1, 0, r1⟩], []⟩ = false := by decide
-- proved by a rule the program does not have
example : check program ⟨[⟨1, 0, ⟨1, [], []⟩⟩], []⟩ = false := by decide
-- proved by a rule of another head
example : check program ⟨[⟨0, 0, r0⟩, ⟨2, 1, r1⟩], []⟩ = false := by decide
-- an undefined atom refuted
example : check program ⟨[], [⟨3, 5⟩]⟩ = false := by decide
-- an undefined atom proved
example : check program ⟨[⟨3, 0, r3⟩], []⟩ = false := by decide
-- refuted at the stage its blocking atom is proved, not after it
example : check program ⟨[⟨0, 0, r0⟩, ⟨1, 1, r1⟩], [⟨2, 1⟩]⟩ = false := by decide

#print axioms Yen.sound
#print axioms Yen.not_both
#print axioms Yen.clean_sound
#print axioms Yen.verify_sound
#print axioms Yen.wfm_fixpoint
#print axioms Yen.verify_wfm
#print axioms Yen.shape_no_cycle
#print axioms Yen.waves_acyclic
#print axioms Yen.relevance
