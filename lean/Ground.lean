import Certificate

/-!
The ground program of yen's rules, and a check that the program Lean grounds covers it.

A rule as yen writes it has variables. Its full ground program has one instance per valuation of the variables
(every string, so it is infinite) whose external atoms (`lt`, `neq`) hold, plus one rule per fact. Lean grounds the
rules by joins over the heads it has, and checks the result covers the full program (`Covers`): then a certificate
checked on it speaks for the full program (`sound`, `clean_sound`), and the grounder is no longer trusted.
-/

namespace Yen

/-- A term of a rule: a variable, or a constant as its `toJSON` key. -/
inductive Term where
  | var (x : String)
  | const (c : String)
deriving DecidableEq, Repr

/-- A ground atom: the relation, then the terms, each its `toJSON` key. -/
abbrev Atom := List String

structure RuleData where
  head : List Term
  pos : List (List Term)
  neg : List (List Term)
deriving Repr

/-- The external relations: decided on ground atoms by a function, never a fact, never a head. -/
structure Ext where
  isExt : String → Bool
  holds : Atom → Bool

variable (E : Ext)

def Term.eval (ν : String → String) : Term → String
  | .var x => ν x
  | .const c => c

def evalAtom (ν : String → String) (a : List Term) : Atom := a.map (Term.eval ν)

def plain (a : List Term) : Bool :=
  match a with
  | .const r :: _ => !E.isExt r
  | _ => true

def extOK (ν : String → String) (R : RuleData) : Bool :=
  (R.pos.filter (!plain E ·)).all (E.holds ∘ evalAtom ν) && !(R.neg.filter (!plain E ·)).any (E.holds ∘ evalAtom ν)

/-- The instance of a rule at a valuation: its external atoms decided, then dropped. -/
def inst (ν : String → String) (R : RuleData) : Rule Atom :=
  ⟨evalAtom ν R.head, (R.pos.filter (plain E)).map (evalAtom ν), (R.neg.filter (plain E)).map (evalAtom ν)⟩

/-- The full ground program of the rules and the facts. -/
def Full (rules : List RuleData) (facts : List Atom) (r : Rule Atom) : Prop :=
  (∃ f ∈ facts, r = ⟨f, [], []⟩) ∨ ∃ R ∈ rules, ∃ ν, extOK E ν R = true ∧ r = inst E ν R

-- ── joins ──

abbrev Subst := List (String × String)

def look : Subst → String → Option String
  | [], _ => none
  | (y, v) :: σ, x => if y = x then some v else look σ x

/-- The substitution as a valuation: an unbound variable is "", and a safe rule never reads one. -/
def valOf (σ : Subst) (x : String) : String := (look σ x).getD ""

def matchTerm (σ : Subst) : Term → String → Option Subst
  | .const k, c => if k = c then some σ else none
  | .var x, c =>
    match look σ x with
    | some v => if v = c then some σ else none
    | none => some ((x, c) :: σ)

def matchAtom (σ : Subst) : List Term → Atom → Option Subst
  | [], [] => some σ
  | t :: ts, c :: cs => (matchTerm σ t c).bind (matchAtom · ts cs)
  | _, _ => none

/-- Every substitution that maps the atoms to atoms of `poss`, extending σ, left to right. -/
def join (poss : List Atom) : List (List Term) → Subst → List Subst
  | [], σ => [σ]
  | a :: as, σ => poss.flatMap fun g =>
    match matchAtom σ a g with
    | some σ' => join poss as σ'
    | none => []

def groundRule (poss : List Atom) (R : RuleData) : List (Rule Atom) :=
  ((join poss (R.pos.filter (plain E)) []).filter fun σ => extOK E (valOf σ) R).map fun σ => inst E (valOf σ) R

/-- A safe rule: each variable of its head, its negative atoms and its external atoms is in a plain positive atom. -/
def safe (R : RuleData) : Bool :=
  (R.head :: R.neg ++ R.pos.filter (!plain E ·)).all fun a => a.all fun
    | .var x => (R.pos.filter (plain E)).any (·.contains (.var x))
    | .const _ => true

def build (rules : List RuleData) (facts : List Atom) (poss : List Atom) : List (Rule Atom) :=
  facts.map (⟨·, [], []⟩) ++ rules.flatMap (groundRule E poss)

/-- G has every instance whose positive atoms are its heads. -/
def covered (rules : List RuleData) (G : List (Rule Atom)) : Bool :=
  rules.all fun R => (groundRule E (G.map (·.head)) R).all (G.contains ·)

-- ── proofs ──

def Agree (σ : Subst) (ν : String → String) : Prop := ∀ x v, look σ x = some v → ν x = v
def Ext' (σ σ' : Subst) : Prop := ∀ x v, look σ x = some v → look σ' x = some v
def Bound (σ : Subst) : Term → Prop
  | .var x => (look σ x).isSome
  | .const _ => True

theorem Ext'.refl (σ : Subst) : Ext' σ σ := fun _ _ h => h
theorem Ext'.trans {a b c : Subst} (h1 : Ext' a b) (h2 : Ext' b c) : Ext' a c := fun x v h => h2 x v (h1 x v h)

theorem Bound.mono {σ σ' : Subst} (h : Ext' σ σ') : ∀ {t}, Bound σ t → Bound σ' t
  | .var x, hb => by
    simp only [Bound] at *
    obtain ⟨v, hv⟩ := Option.isSome_iff_exists.mp hb
    simp [h x v hv]
  | .const _, _ => trivial

theorem matchTerm_complete {σ ν} (hA : Agree σ ν) (t : Term) :
    ∃ σ', matchTerm σ t (t.eval ν) = some σ' ∧ Agree σ' ν ∧ Ext' σ σ' ∧ Bound σ' t := by
  cases t with
  | const k => exact ⟨σ, by simp [matchTerm, Term.eval], hA, Ext'.refl σ, trivial⟩
  | var x =>
    cases hx : look σ x with
    | some v =>
      have := hA x v hx
      exact ⟨σ, by simp [matchTerm, Term.eval, hx, this], hA, Ext'.refl σ, by simp [Bound, hx]⟩
    | none =>
      refine ⟨(x, ν x) :: σ, by simp [matchTerm, Term.eval, hx], ?_, ?_, by simp [Bound, look]⟩
      · intro y v hy
        simp only [look] at hy
        split at hy
        · cases hy; subst_vars; rfl
        · exact hA y v hy
      · intro y v hy
        simp only [look]
        split
        · subst_vars; rw [hx] at hy; cases hy
        · exact hy

theorem matchAtom_complete {ν} : ∀ (a : List Term) {σ}, Agree σ ν →
    ∃ σ', matchAtom σ a (evalAtom ν a) = some σ' ∧ Agree σ' ν ∧ Ext' σ σ' ∧ ∀ t ∈ a, Bound σ' t
  | [], σ, hA => ⟨σ, by simp [matchAtom, evalAtom], hA, Ext'.refl σ, by simp⟩
  | t :: ts, σ, hA => by
    obtain ⟨σ1, h1, hA1, hE1, hB1⟩ := matchTerm_complete hA t
    obtain ⟨σ2, h2, hA2, hE2, hB2⟩ := matchAtom_complete ts hA1
    refine ⟨σ2, ?_, hA2, hE1.trans hE2, ?_⟩
    · have : evalAtom ν (t :: ts) = t.eval ν :: evalAtom ν ts := rfl
      rw [this]
      simp [matchAtom, h1, h2]
    · intro u hu
      rcases List.mem_cons.mp hu with rfl | hu
      · exact Bound.mono hE2 hB1
      · exact hB2 u hu

theorem join_complete {ν} {poss : List Atom} : ∀ (as : List (List Term)) {σ}, Agree σ ν →
    (∀ a ∈ as, evalAtom ν a ∈ poss) →
    ∃ σ' ∈ join poss as σ, Agree σ' ν ∧ ∀ a ∈ as, ∀ t ∈ a, Bound σ' t
  | [], σ, hA, _ => ⟨σ, by simp [join], hA, by simp⟩
  | a :: as, σ, hA, hin => by
    obtain ⟨σ1, h1, hA1, hE1, hB1⟩ := matchAtom_complete a hA
    obtain ⟨σ2, h2, hA2, hB2⟩ := join_complete as hA1 (fun b hb => hin b (List.mem_cons_of_mem _ hb))
    refine ⟨σ2, ?_, hA2, ?_⟩
    · simp only [join, List.mem_flatMap]
      exact ⟨evalAtom ν a, hin a List.mem_cons_self, by simp [h1, h2]⟩
    · intro b hb t ht
      rcases List.mem_cons.mp hb with rfl | hb
      · -- σ2 extends σ1: the join only adds bindings
        exact join_mono as σ1 σ2 h2 (hB1 t ht)
      · exact hB2 b hb t ht
where
  join_mono : ∀ (as : List (List Term)) (σ σ' : Subst), σ' ∈ join poss as σ → ∀ {t}, Bound σ t → Bound σ' t
    | [], σ, σ', h, _, hb => by simp [join] at h; subst h; exact hb
    | a :: as, σ, σ', h, _, hb => by
      simp only [join, List.mem_flatMap] at h
      obtain ⟨g, -, hg⟩ := h
      cases hm : matchAtom σ a g with
      | none => simp [hm] at hg
      | some σ1 =>
        simp only [hm] at hg
        exact join_mono as σ1 σ' hg (Bound.mono (matchAtom_ext a g hm) hb)
  matchAtom_ext : ∀ (a : List Term) (g : Atom) {σ σ'}, matchAtom σ a g = some σ' → Ext' σ σ'
    | [], [], σ, σ', h => by simp [matchAtom] at h; subst h; exact Ext'.refl _
    | [], _ :: _, _, _, h => by simp [matchAtom] at h
    | _ :: _, [], _, _, h => by simp [matchAtom] at h
    | t :: ts, c :: cs, σ, σ', h => by
      simp only [matchAtom, Option.bind_eq_some_iff] at h
      obtain ⟨σ1, h1, h2⟩ := h
      exact (matchTerm_ext t c h1).trans (matchAtom_ext ts cs h2)
  matchTerm_ext : ∀ (t : Term) (c : String) {σ σ'}, matchTerm σ t c = some σ' → Ext' σ σ'
    | .const k, c, σ, σ', h => by
      simp only [matchTerm] at h; split at h <;> simp at h; subst h; exact Ext'.refl _
    | .var x, c, σ, σ', h => by
      simp only [matchTerm] at h
      split at h
      · split at h <;> simp at h; subst h; exact Ext'.refl _
      · rename_i hx
        simp at h; subst h
        intro y v hy
        simp only [look]
        split
        · subst_vars; rw [hx] at hy; cases hy
        · exact hy

theorem eval_valOf {σ ν} (hA : Agree σ ν) : ∀ {t}, Bound σ t → t.eval (valOf σ) = t.eval ν
  | .var x, hb => by
    simp only [Bound] at hb
    obtain ⟨v, hv⟩ := Option.isSome_iff_exists.mp hb
    simp [Term.eval, valOf, hv, hA x v hv]
  | .const _, _ => rfl

theorem evalAtom_valOf {σ ν} (hA : Agree σ ν) {a : List Term} (hb : ∀ t ∈ a, Bound σ t) :
    evalAtom (valOf σ) a = evalAtom ν a :=
  List.map_congr_left fun t ht => eval_valOf hA (hb t ht)

/-- The grounding is sound: each rule `build` gives is a rule of the full program. -/
theorem build_full {rules facts poss} : ∀ r ∈ build E rules facts poss, Full E rules facts r := by
  intro r hr
  simp only [build, List.mem_append, List.mem_map, List.mem_flatMap, groundRule, List.mem_filter] at hr
  rcases hr with ⟨f, hf, rfl⟩ | ⟨R, hR, σ, ⟨-, hok⟩, rfl⟩
  · exact Or.inl ⟨f, hf, rfl⟩
  · exact Or.inr ⟨R, hR, valOf σ, hok, rfl⟩

/-- The grounding is complete: on safe rules, `covered` gives every rule of the full program whose positive atoms
are heads of G. -/
theorem covers {rules facts poss} (hs : rules.all (safe E) = true)
    (hc : covered E rules (build E rules facts poss) = true) :
    Covers (build E rules facts poss) (Full E rules facts) := by
  refine ⟨build_full E, ?_⟩
  intro r hr hposs
  rcases hr with ⟨f, hf, rfl⟩ | ⟨R, hR, ν, hok, rfl⟩
  · exact List.mem_append_left _ (List.mem_map.mpr ⟨f, hf, rfl⟩)
  · let G := build E rules facts poss
    have hin : ∀ a ∈ R.pos.filter (plain E), evalAtom ν a ∈ G.map (·.head) := by
      intro a ha
      have := hposs (evalAtom ν a) (List.mem_map_of_mem ha)
      obtain ⟨g, hg, hgh⟩ := List.any_eq_true.mp this
      exact List.mem_map.mpr ⟨g, hg, by simpa using hgh⟩
    obtain ⟨σ, hσ, hA, hB⟩ := join_complete (R.pos.filter (plain E)) (fun x v h => by rw [show look [] x = none from rfl] at h; cases h) hin
    -- every variable of the rule is bound by its plain positive atoms
    have hsafe := List.all_eq_true.mp hs R hR
    have hbound : ∀ a ∈ R.head :: R.neg ++ R.pos.filter (!plain E ·), ∀ t ∈ a, Bound σ t := by
      intro a ha t ht
      have := List.all_eq_true.mp (List.all_eq_true.mp hsafe a ha) t ht
      cases t with
      | const _ => trivial
      | var x =>
        obtain ⟨b, hb, hbx⟩ := List.any_eq_true.mp this
        exact hB b hb (.var x) (by simpa using hbx)
    have hall : ∀ a, (a ∈ R.pos ∨ a ∈ R.neg ∨ a = R.head) → evalAtom (valOf σ) a = evalAtom ν a := by
      intro a ha
      apply evalAtom_valOf hA
      by_cases hp : plain E a = true
      · rcases ha with ha | ha | rfl
        · exact hB a (List.mem_filter.mpr ⟨ha, hp⟩)
        · exact hbound a (by simp [ha])
        · exact hbound _ (by simp)
      · rcases ha with ha | ha | rfl
        · exact hbound a (by simp [ha, hp])
        · exact hbound a (by simp [ha])
        · exact hbound _ (by simp)
    have hinst : inst E (valOf σ) R = inst E ν R := by
      simp only [inst, Rule.mk.injEq]
      refine ⟨hall _ (Or.inr (Or.inr rfl)), ?_, ?_⟩
      · exact List.map_congr_left fun a ha => hall a (Or.inl (List.mem_filter.mp ha).1)
      · exact List.map_congr_left fun a ha => hall a (Or.inr (Or.inl (List.mem_filter.mp ha).1))
    have hext : extOK E (valOf σ) R = extOK E ν R := by
      have hp : (R.pos.filter (!plain E ·)).map (evalAtom (valOf σ)) = (R.pos.filter (!plain E ·)).map (evalAtom ν) :=
        List.map_congr_left fun a ha => hall a (Or.inl (List.mem_filter.mp ha).1)
      have hn : (R.neg.filter (!plain E ·)).map (evalAtom (valOf σ)) = (R.neg.filter (!plain E ·)).map (evalAtom ν) :=
        List.map_congr_left fun a ha => hall a (Or.inr (Or.inl (List.mem_filter.mp ha).1))
      simp only [extOK, ← List.all_map, ← List.any_map, hp, hn]
    have hmem : inst E ν R ∈ groundRule E (G.map (·.head)) R := by
      rw [← hinst]
      exact List.mem_map_of_mem (List.mem_filter.mpr ⟨hσ, hext ▸ hok⟩)
    have := List.all_eq_true.mp (List.all_eq_true.mp hc R hR) _ hmem
    simpa using this

/-- The verdict Lean checks: safe rules, a grounding that covers them, and a clean certificate on it. -/
def verify (bad : Atom → Bool) (rules : List RuleData) (facts poss : List Atom) (c : Certificate Atom) : Bool :=
  rules.all (safe E) && covered E rules (build E rules facts poss) && clean bad (build E rules facts poss) c

/-- On a verified verdict, every violation is false in every interpretation closed under W_P of the full ground
program of the rules and facts, the well-founded model among them: no violation is true, none undefined. -/
theorem verify_sound {bad rules facts poss c} (h : verify E bad rules facts poss c = true) {T F : Atom → Prop}
    (hI : Closed (Full E rules facts) T F) : ∀ a, bad a = true → F a := by
  simp only [verify, Bool.and_eq_true] at h
  exact clean_sound h.2 (covers E h.1.1 h.1.2) hI

end Yen
