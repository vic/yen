/-!
Deploy waves, checked. `lib.graphs.layers succ` puts each node in the first wave after all its successors (what it
depends on). `wavesOk` accepts waves when each node of the graph is in exactly one wave and every edge goes from a later
wave to an earlier one. `waves_respect`: every dependency is deployed in an earlier wave. `waves_acyclic`: then the
graph has no cycle, so a cycle can never be given waves.
-/

namespace Yen

abbrev Edge := String × String

/-- The wave of a node: the index of the first wave that has it. -/
def waveOf (layers : List (List String)) (n : String) : Option Nat :=
  layers.findIdx? (·.contains n)

def nodesOf (edges : List Edge) : List String := edges.flatMap fun (a, b) => [a, b]

def wavesOk (edges : List Edge) (layers : List (List String)) : Bool :=
  (layers.flatten.eraseDups.length == layers.flatten.length)
    && (nodesOf edges).all (fun n => (waveOf layers n).isSome)
    && edges.all fun (a, b) =>
      match waveOf layers a, waveOf layers b with
      | some i, some j => decide (j < i)
      | _, _ => false

theorem waves_respect {edges layers} (h : wavesOk edges layers = true) :
    ∀ e ∈ edges, ∃ i j, waveOf layers e.1 = some i ∧ waveOf layers e.2 = some j ∧ j < i := by
  simp only [wavesOk, Bool.and_eq_true, List.all_eq_true] at h
  intro e he
  have := h.2 e he
  revert this
  cases ha : waveOf layers e.1 <;> cases hb : waveOf layers e.2 <;> simp

/-- A path of one edge or more. -/
inductive Path (edges : List Edge) : String → String → Prop
  | one {a b} : (a, b) ∈ edges → Path edges a b
  | cons {a b c} : (a, b) ∈ edges → Path edges b c → Path edges a c

theorem path_down {edges layers} (h : wavesOk edges layers = true) {a b} (p : Path edges a b) :
    ∃ i j, waveOf layers a = some i ∧ waveOf layers b = some j ∧ j < i := by
  induction p with
  | one he => exact waves_respect h _ he
  | cons he _ ih =>
    obtain ⟨i, j, ha, hb, hij⟩ := waves_respect h _ he
    obtain ⟨j', k, hb', hc, hjk⟩ := ih
    rw [hb] at hb'; cases hb'
    exact ⟨i, k, ha, hc, Nat.lt_trans hjk hij⟩

theorem waves_acyclic {edges layers} (h : wavesOk edges layers = true) : ∀ a, ¬Path edges a a := by
  intro a p
  obtain ⟨i, j, ha, hb, hij⟩ := path_down h p
  rw [ha] at hb; cases hb
  exact Nat.lt_irrefl _ hij

end Yen
