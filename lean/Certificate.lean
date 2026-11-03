/-!
The trusted checker of yen certificates, `lib.datalog.checkCertificate` (lib/datalog.nix), and its proofs.

A certificate gives each decided atom a stage. The checker accepts it when each proved atom has a rule of the
program whose positive atoms are proved and negative atoms refuted at smaller stages, and every rule of a refuted
atom has a positive atom refuted at a stage no later, or a negative atom proved at a smaller stage.

`sound`: on an accepted certificate, proved atoms are true and refuted atoms false in every interpretation closed
under W_P (Van Gelder, Ross, Schlipf 1991, Def 3.4), so in the well-founded model, its least fixpoint.
`disjoint`: no atom of an accepted certificate is both proved and refuted.
-/

namespace Yen

structure Rule (α : Type) where
  head : α
  pos : List α
  neg : List α
deriving DecidableEq, Repr

structure Proved (α : Type) where
  atom : α
  stage : Nat
  rule : Rule α
deriving Repr

structure Refuted (α : Type) where
  atom : α
  stage : Nat
deriving Repr

structure Certificate (α : Type) where
  proved : List (Proved α)
  refuted : List (Refuted α)
deriving Repr

variable {α : Type} [DecidableEq α]

-- the stage of an atom: its first entry, as `builtins.listToAttrs` keeps the first of a repeated name
def provedStage (c : Certificate α) (a : α) : Option Nat :=
  (c.proved.find? (·.atom == a)).map (·.stage)

def refutedStage (c : Certificate α) (a : α) : Option Nat :=
  (c.refuted.find? (·.atom == a)).map (·.stage)

def before (m : α → Option Nat) (s : Nat) (x : α) : Bool :=
  match m x with
  | some t => decide (t < s)
  | none => false

def notAfter (m : α → Option Nat) (s : Nat) (x : α) : Bool :=
  match m x with
  | some t => decide (t ≤ s)
  | none => false

def supported (P : List (Rule α)) (c : Certificate α) (e : Proved α) : Bool :=
  P.contains e.rule && e.rule.head == e.atom
    && e.rule.pos.all (before (provedStage c) e.stage)
    && e.rule.neg.all (before (refutedStage c) e.stage)

def unfounded (P : List (Rule α)) (c : Certificate α) (e : Refuted α) : Bool :=
  P.all fun r =>
    r.head != e.atom
      || r.pos.any (notAfter (refutedStage c) e.stage)
      || r.neg.any (before (provedStage c) e.stage)

def check (P : List (Rule α)) (c : Certificate α) : Bool :=
  c.proved.all (supported P c) && c.refuted.all (unfounded P c)

/-- An interpretation (T true, F false) closed under W_P of a ground program P, finite or not: it holds the head of
each rule whose body it makes true, and every set unfounded with respect to it (VRS 1991, Def 3.1) is false in it. -/
structure Closed (P : Rule α → Prop) (T F : α → Prop) : Prop where
  rules : ∀ r, P r → (∀ p ∈ r.pos, T p) → (∀ n ∈ r.neg, F n) → T r.head
  unfounded : ∀ U : α → Prop,
    (∀ a, U a → ∀ r, P r → r.head = a → (∃ p ∈ r.pos, F p ∨ U p) ∨ ∃ n ∈ r.neg, T n) → ∀ a, U a → F a

-- the atom is the head of a rule of G: it may hold
def poss (G : List (Rule α)) (p : α) : Bool := G.any (·.head == p)

/-- G covers the ground program P: its rules are rules of P, and it has every rule of P whose positive atoms are
heads of G. The rules of P it leaves out can never fire, so the certificate on G speaks for P. -/
def Covers (G : List (Rule α)) (P : Rule α → Prop) : Prop :=
  (∀ r ∈ G, P r) ∧ ∀ r, P r → (∀ p ∈ r.pos, poss G p = true) → r ∈ G

theorem covers_self (G : List (Rule α)) : Covers G (· ∈ G) := ⟨fun _ h => h, fun _ h _ => h⟩

omit [DecidableEq α] in
theorem before_iff {m : α → Option Nat} {s x} : before m s x = true ↔ ∃ t, m x = some t ∧ t < s := by
  unfold before; cases m x <;> simp

omit [DecidableEq α] in
theorem notAfter_iff {m : α → Option Nat} {s x} : notAfter m s x = true ↔ ∃ t, m x = some t ∧ t ≤ s := by
  unfold notAfter; cases m x <;> simp

theorem provedStage_some {c : Certificate α} {a s} (h : provedStage c a = some s) :
    ∃ e ∈ c.proved, e.atom = a ∧ e.stage = s := by
  unfold provedStage at h
  cases hf : c.proved.find? (·.atom == a) with
  | none => simp [hf] at h
  | some e =>
    simp [hf] at h
    exact ⟨e, List.mem_of_find?_eq_some hf, by simpa using List.find?_some hf, h⟩

theorem refutedStage_some {c : Certificate α} {a s} (h : refutedStage c a = some s) :
    ∃ e ∈ c.refuted, e.atom = a ∧ e.stage = s := by
  unfold refutedStage at h
  cases hf : c.refuted.find? (·.atom == a) with
  | none => simp [hf] at h
  | some e =>
    simp [hf] at h
    exact ⟨e, List.mem_of_find?_eq_some hf, by simpa using List.find?_some hf, h⟩

theorem provedStage_mem {c : Certificate α} {e} (h : e ∈ c.proved) : ∃ s, provedStage c e.atom = some s := by
  unfold provedStage
  cases hf : c.proved.find? (·.atom == e.atom) with
  | none => exact absurd (List.find?_eq_none.mp hf e h) (by simp)
  | some e' => exact ⟨e'.stage, by simp [hf]⟩

theorem refutedStage_mem {c : Certificate α} {e} (h : e ∈ c.refuted) : ∃ s, refutedStage c e.atom = some s := by
  unfold refutedStage
  cases hf : c.refuted.find? (·.atom == e.atom) with
  | none => exact absurd (List.find?_eq_none.mp hf e h) (by simp)
  | some e' => exact ⟨e'.stage, by simp [hf]⟩

theorem supported_iff {P : List (Rule α)} {c e} : supported P c e = true ↔
    e.rule ∈ P ∧ e.rule.head = e.atom
      ∧ (∀ p ∈ e.rule.pos, ∃ t, provedStage c p = some t ∧ t < e.stage)
      ∧ ∀ n ∈ e.rule.neg, ∃ t, refutedStage c n = some t ∧ t < e.stage := by
  simp [supported, List.all_eq_true, before_iff, and_assoc]

theorem unfounded_iff {P : List (Rule α)} {c e} : unfounded P c e = true ↔
    ∀ r ∈ P, r.head = e.atom →
      (∃ p ∈ r.pos, ∃ t, refutedStage c p = some t ∧ t ≤ e.stage)
      ∨ ∃ n ∈ r.neg, ∃ t, provedStage c n = some t ∧ t < e.stage := by
  simp only [unfounded, List.all_eq_true, Bool.or_eq_true, bne_iff_ne, ne_eq, List.any_eq_true, notAfter_iff,
    before_iff]
  constructor
  · intro h r hr hh
    rcases h r hr with (h | h) | h
    · exact absurd hh h
    · exact Or.inl h
    · exact Or.inr h
  · intro h r hr
    by_cases hh : r.head = e.atom
    · rcases h r hr hh with h | h
      · exact Or.inl (Or.inr h)
      · exact Or.inr h
    · exact Or.inl (Or.inl hh)

theorem check_iff {P : List (Rule α)} {c} : check P c = true ↔
    (∀ e ∈ c.proved, supported P c e = true) ∧ ∀ e ∈ c.refuted, unfounded P c e = true := by
  simp [check, List.all_eq_true]


theorem poss_of_mem {G : List (Rule α)} {r} (h : r ∈ G) : poss G r.head = true :=
  List.any_eq_true.mpr ⟨r, h, by simp⟩

theorem not_all_poss {G : List (Rule α)} {ps : List α} (h : ps.all (poss G) = false) :
    ∃ p ∈ ps, poss G p = false := by
  simpa using h

/-- The atoms that are heads of no rule of G are false: every rule of P for one of them has such a positive atom. -/
theorem unpossible {G : List (Rule α)} {P : Rule α → Prop} {T F : α → Prop} (hc : Covers G P)
    (hI : Closed P T F) : ∀ a, poss G a = false → F a := by
  refine hI.unfounded (fun a => poss G a = false) ?_
  intro a ha r hP hra
  cases hall : r.pos.all (poss G) with
  | true =>
    have := poss_of_mem (hc.2 r hP (by simpa using hall))
    rw [hra, ha] at this
    exact absurd this (by simp)
  | false =>
    obtain ⟨p, hp, hp'⟩ := not_all_poss hall
    exact Or.inl ⟨p, hp, Or.inr hp'⟩

/-- By induction on the stage: below each stage, proved atoms are true and refuted atoms false. -/
theorem below {G : List (Rule α)} {P : Rule α → Prop} {c : Certificate α} {T F : α → Prop}
    (h : check G c = true) (hc : Covers G P) (hI : Closed P T F) (s : Nat) :
    (∀ a t, provedStage c a = some t → t < s → T a) ∧ (∀ a t, refutedStage c a = some t → t < s → F a) := by
  obtain ⟨hp, hr⟩ := check_iff.mp h
  induction s with
  | zero => exact ⟨fun _ _ _ ht => absurd ht (Nat.not_lt_zero _), fun _ _ _ ht => absurd ht (Nat.not_lt_zero _)⟩
  | succ s ih =>
    obtain ⟨ihT, ihF⟩ := ih
    -- the atoms refuted at stage s or before, with the heads of no rule of G, form an unfounded set
    have hF : ∀ a t, refutedStage c a = some t → t < s + 1 → F a := by
      intro a t ht hts
      refine hI.unfounded (fun a => (∃ t, refutedStage c a = some t ∧ t ≤ s) ∨ poss G a = false) ?_ a
        (Or.inl ⟨t, ht, Nat.lt_succ_iff.mp hts⟩)
      intro a hU r hP hra
      by_cases hrG : r ∈ G
      · rcases hU with ⟨t, ht, hts⟩ | hno
        · obtain ⟨e, he, rfl, rfl⟩ := refutedStage_some ht
          rcases unfounded_iff.mp (hr e he) r hrG hra with ⟨p, hp, t', hp', ht'⟩ | ⟨n, hn, t', hn', ht'⟩
          · exact Or.inl ⟨p, hp, Or.inr (Or.inl ⟨t', hp', Nat.le_trans ht' hts⟩)⟩
          · exact Or.inr ⟨n, hn, ihT n t' hn' (Nat.lt_of_lt_of_le ht' hts)⟩
        · have := poss_of_mem hrG
          rw [hra, hno] at this
          exact absurd this (by simp)
      · cases hall : r.pos.all (poss G) with
        | true => exact absurd (hc.2 r hP (by simpa using hall)) hrG
        | false =>
          obtain ⟨p, hp, hp'⟩ := not_all_poss hall
          exact Or.inl ⟨p, hp, Or.inr (Or.inr hp')⟩
    refine ⟨?_, hF⟩
    intro a t ht hts
    rcases Nat.lt_succ_iff_lt_or_eq.mp hts with hlt | rfl
    · exact ihT a t ht hlt
    · obtain ⟨e, he, rfl, rfl⟩ := provedStage_some ht
      obtain ⟨hrP, hhead, hpos, hneg⟩ := supported_iff.mp (hp e he)
      rw [← hhead]
      apply hI.rules e.rule (hc.1 _ hrP)
      · intro p hp'
        obtain ⟨t', h', ht'⟩ := hpos p hp'
        exact ihT p t' h' ht'
      · intro n hn
        obtain ⟨t', h', ht'⟩ := hneg n hn
        exact ihF n t' h' ht'

/-- Soundness: a certificate accepted on G is true in every interpretation closed under W_P of any ground program
that G covers; G covers itself, so this holds for G's own well-founded model too. -/
theorem sound {G : List (Rule α)} {P : Rule α → Prop} {c : Certificate α} (h : check G c = true)
    (hc : Covers G P) {T F : α → Prop} (hI : Closed P T F) :
    (∀ e ∈ c.proved, T e.atom) ∧ ∀ e ∈ c.refuted, F e.atom := by
  refine ⟨fun e he => ?_, fun e he => ?_⟩
  · obtain ⟨s, hs⟩ := provedStage_mem he
    exact (below h hc hI (s + 1)).1 e.atom s hs (Nat.lt_succ_self s)
  · obtain ⟨s, hs⟩ := refutedStage_mem he
    exact (below h hc hI (s + 1)).2 e.atom s hs (Nat.lt_succ_self s)

/-- Disjointness, without a check of its own: an atom both proved and refuted has a rule whose blocking atom is
also both, with a smaller sum of its two stages, and the sum cannot descend forever. -/
theorem disjoint {P : List (Rule α)} {c : Certificate α} (h : check P c = true) :
    ∀ n a t f, t + f < n → provedStage c a = some t → refutedStage c a = some f → False := by
  obtain ⟨hp, hr⟩ := check_iff.mp h
  intro n
  induction n with
  | zero => intro _ _ _ hn; exact absurd hn (Nat.not_lt_zero _)
  | succ n ih =>
    intro a t f hn ht hf
    obtain ⟨e, he, rfl, rfl⟩ := provedStage_some ht
    obtain ⟨e', he', hatom, rfl⟩ := refutedStage_some hf
    obtain ⟨hrP, hhead, hpos, hneg⟩ := supported_iff.mp (hp e he)
    rcases unfounded_iff.mp (hr e' he') e.rule hrP (hhead.trans hatom.symm) with
      ⟨p, hp', f', hpf, hf'⟩ | ⟨q, hq, t', hqt, ht'⟩
    · obtain ⟨t', hpt, ht'⟩ := hpos p hp'
      exact ih p t' f' (by omega) hpt hpf
    · obtain ⟨f', hqf, hf'⟩ := hneg q hq
      exact ih q t' f' (by omega) hqt hqf

theorem not_both {P : List (Rule α)} {c : Certificate α} (h : check P c = true) {a t f}
    (ht : provedStage c a = some t) (hf : refutedStage c a = some f) : False :=
  disjoint h (t + f + 1) a t f (Nat.lt_succ_self _) ht hf


/-- A clean verdict: the checker accepts the certificate and it refutes the head of every rule that derives a
violation. -/
def clean (bad : α → Bool) (G : List (Rule α)) (c : Certificate α) : Bool :=
  check G c && G.all fun r => !bad r.head || (refutedStage c r.head).isSome

/-- On a clean verdict every violation is false, the ones G never derives too: none is true, none undefined. -/
theorem clean_sound {bad : α → Bool} {G : List (Rule α)} {P : Rule α → Prop} {c : Certificate α}
    (h : clean bad G c = true) (hc : Covers G P) {T F : α → Prop} (hI : Closed P T F) :
    ∀ a, bad a = true → F a := by
  simp only [clean, Bool.and_eq_true, List.all_eq_true, Bool.or_eq_true, Bool.not_eq_true'] at h
  intro a hbad
  cases hp : poss G a with
  | false => exact unpossible hc hI a hp
  | true =>
    obtain ⟨r, hr, hra⟩ := List.any_eq_true.mp hp
    have hra : r.head = a := by simpa using hra
    rcases h.2 r hr with hb | hs
    · rw [hra, hbad] at hb; exact absurd hb (by simp)
    · obtain ⟨s, hs⟩ := Option.isSome_iff_exists.mp hs
      obtain ⟨e, he, hatom, -⟩ := refutedStage_some hs
      rw [← hra, ← hatom]
      exact (sound h.1 hc hI).2 e he

end Yen
