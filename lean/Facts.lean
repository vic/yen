import Ground

/-!
The shape of the facts yen exports. Nix turns the fleet into facts and the checker trusts that step; Lean still
checks their shape: every id a fact names is a scope, each scope has one kind and at most one parent, and every
scope reaches a root. `no_cycle`: then no scope is its own ancestor.
Facts: [scope id], [instance id kind name], [parent id parent], [kind kind id], [has aspect id], [edge sink from to],
[val field id value], each term its `toJSON` key.
-/

namespace Yen

-- a relation name as its `toJSON` key
def rel (r : String) : String := "\"" ++ r ++ "\""

def scopes (facts : List Atom) : List String :=
  facts.filterMap fun
    | [r, s] => if r == rel "scope" then some s else none
    | _ => none

/-- The scope ids a fact names. -/
def ids : Atom → List String
  | [r, a, b, c] => if r == rel "instance" then [a] else if r == rel "edge" then [b, c] else if r == rel "val" then [b] else []
  | [r, a, b] => if r == rel "parent" then [a, b] else if r == rel "kind" || r == rel "has" then [b] else []
  | _ => []

def up (facts : List Atom) (s : String) : Option String :=
  facts.findSome? fun
    | [r, c, p] => if r == rel "parent" && c == s then some p else none
    | _ => none

/-- The ancestor j steps up. -/
def upN (facts : List Atom) : Nat → String → Option String
  | 0, s => some s
  | j + 1, s => (up facts s).bind (upN facts j)

/-- The scope reaches a root (a scope with no parent) in at most k steps. -/
def reaches (facts : List Atom) : Nat → String → Bool
  | 0, _ => false
  | k + 1, s =>
    match up facts s with
    | none => true
    | some p => reaches facts k p

def count (facts : List Atom) (r : String) (s : String) (at_ : Nat) : Nat :=
  (facts.filter fun f => f.head? == some (rel r) && f[at_]? == some s).length

def shapeOk (facts : List Atom) : Bool :=
  let ss := scopes facts
  facts.all (fun f => (ids f).all ss.contains)
    && ss.all fun s => count facts "kind" s 2 == 1 && count facts "parent" s 1 ≤ 1 && reaches facts (ss.length + 1) s

theorem upN_add (facts : List Atom) : ∀ a b s, upN facts (a + b) s = (upN facts a s).bind (upN facts b)
  | 0, b, s => by simp [upN]
  | a + 1, b, s => by
    rw [Nat.add_right_comm, upN, upN, Option.bind_assoc]
    congr 1
    funext y
    exact upN_add facts a b y

theorem reaches_root (facts : List Atom) : ∀ k s, reaches facts k s = true →
    ∃ j r, upN facts j s = some r ∧ up facts r = none
  | 0, _, h => by simp [reaches] at h
  | k + 1, s, h => by
    simp only [reaches] at h
    cases hu : up facts s with
    | none => exact ⟨0, s, rfl, hu⟩
    | some p =>
      rw [hu] at h
      obtain ⟨j, r, hj, hr⟩ := reaches_root facts k p h
      exact ⟨j + 1, r, by simp [upN, hu, hj], hr⟩

theorem upN_mul {facts : List Atom} {m s} (h : upN facts m s = some s) : ∀ t, upN facts (m * t) s = some s
  | 0 => rfl
  | t + 1 => by rw [Nat.mul_succ, upN_add, upN_mul h t]; simpa using h

/-- A scope that reaches a root is not its own ancestor. -/
theorem no_cycle {facts : List Atom} {k s} (h : reaches facts k s = true) : ∀ m, 0 < m → upN facts m s ≠ some s := by
  intro m hm hc
  obtain ⟨j, r, hj, hr⟩ := reaches_root facts k s h
  have hnone : upN facts (j + 1) s = none := by
    rw [upN_add, hj]; simp [upN, hr]
  obtain ⟨d, hd⟩ : ∃ d, m * (j + 1) = (j + 1) + d := ⟨m * (j + 1) - (j + 1), by
    have : j + 1 ≤ m * (j + 1) := Nat.le_mul_of_pos_left _ hm
    omega⟩
  have := upN_mul hc (j + 1)
  rw [hd, upN_add, hnone] at this
  simp at this

theorem shape_no_cycle {facts : List Atom} (h : shapeOk facts = true) :
    ∀ s ∈ scopes facts, ∀ m, 0 < m → upN facts m s ≠ some s := by
  intro s hs
  simp only [shapeOk, Bool.and_eq_true, List.all_eq_true] at h
  exact no_cycle (h.2 s hs).2

end Yen
