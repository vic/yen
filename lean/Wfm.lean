import Ground

/-!
The well-founded model, defined in Lean: the least fixpoint of the well-founded operator W_P (Van Gelder, Ross,
Schlipf 1991, Def 3.4), for any ground program, finite or not.

W_P(I) makes true the heads of rules whose body I makes true (T_P), and false the atoms of every set unfounded with
respect to I (U_P, Def 3.1). `Closed P T F` says W_P(I) ⊆ I. By Knaster–Tarski the meet of every closed interpretation
is the least fixpoint: `wfm_fixpoint`, `wfm_least`. So `verify_wfm`: on a verified verdict, every violation is false in
the well-founded model of the full ground program. Its consistency (no atom both true and false) is VRS 1991, Thm 5.4.
-/

namespace Yen

variable {α : Type} (P : Rule α → Prop)

/-- T_P(I): the head of a rule whose body I makes true. -/
def WT (T F : α → Prop) (a : α) : Prop :=
  ∃ r, P r ∧ r.head = a ∧ (∀ p ∈ r.pos, T p) ∧ ∀ n ∈ r.neg, F n

def Unfounded (T F U : α → Prop) : Prop :=
  ∀ a, U a → ∀ r, P r → r.head = a → (∃ p ∈ r.pos, F p ∨ U p) ∨ ∃ n ∈ r.neg, T n

/-- U_P(I): an atom of a set unfounded with respect to I. -/
def WF (T F : α → Prop) (a : α) : Prop := ∃ U, Unfounded P T F U ∧ U a

/-- The well-founded model: true (false) in every interpretation closed under W_P. -/
def WfmT (a : α) : Prop := ∀ T F, Closed P T F → T a
def WfmF (a : α) : Prop := ∀ T F, Closed P T F → F a

variable {P}

theorem closed_of {T F : α → Prop} (hT : ∀ a, WT P T F a → T a) (hF : ∀ a, WF P T F a → F a) : Closed P T F :=
  ⟨fun r hr hp hn => hT _ ⟨r, hr, rfl, hp, hn⟩, fun U hU a ha => hF a ⟨U, hU, ha⟩⟩

theorem unfounded_mono {T F T' F' U : α → Prop} (hT : ∀ a, T a → T' a) (hF : ∀ a, F a → F' a)
    (h : Unfounded P T F U) : Unfounded P T' F' U := by
  intro a ha r hr hra
  rcases h a ha r hr hra with ⟨p, hp, hp'⟩ | ⟨n, hn, hn'⟩
  · exact Or.inl ⟨p, hp, hp'.imp (hF p) id⟩
  · exact Or.inr ⟨n, hn, hT n hn'⟩

/-- The meet of the closed interpretations is closed. -/
theorem wfm_closed : Closed P (WfmT P) (WfmF P) := by
  refine closed_of (fun a ⟨r, hr, hra, hp, hn⟩ T F hI => ?_) (fun a ⟨U, hU, ha⟩ T F hI => ?_)
  · exact hra ▸ hI.rules r hr (fun p h => hp p h T F hI) (fun n h => hn n h T F hI)
  · exact hI.unfounded U (unfounded_mono (fun _ h => h T F hI) (fun _ h => h T F hI) hU) a ha

/-- It is below every closed interpretation, so below every fixpoint of W_P. -/
theorem wfm_least {T F : α → Prop} (hI : Closed P T F) :
    (∀ a, WfmT P a → T a) ∧ ∀ a, WfmF P a → F a :=
  ⟨fun _ h => h T F hI, fun _ h => h T F hI⟩

/-- It is a fixpoint of W_P: W_P of it is closed too, so it is below its own image. -/
theorem wfm_fixpoint :
    (∀ a, WfmT P a ↔ WT P (WfmT P) (WfmF P) a) ∧ ∀ a, WfmF P a ↔ WF P (WfmT P) (WfmF P) a := by
  have hc := wfm_closed (P := P)
  have hT : ∀ a, WT P (WfmT P) (WfmF P) a → WfmT P a := fun a ⟨r, hr, hra, hp, hn⟩ => hra ▸ hc.rules r hr hp hn
  have hF : ∀ a, WF P (WfmT P) (WfmF P) a → WfmF P a := fun a ⟨U, hU, ha⟩ => hc.unfounded U hU a ha
  have himg : Closed P (WT P (WfmT P) (WfmF P)) (WF P (WfmT P) (WfmF P)) := by
    refine closed_of (fun a ⟨r, hr, hra, hp, hn⟩ => ⟨r, hr, hra, fun p h => hT p (hp p h), fun n h => hF n (hn n h)⟩)
      (fun a ⟨U, hU, ha⟩ => ⟨U, unfounded_mono hT hF hU, ha⟩)
  exact ⟨fun a => ⟨fun h => h _ _ himg, hT a⟩, fun a => ⟨fun h => h _ _ himg, hF a⟩⟩

/-- One direction of `relevance`: from any closed interpretation of P', everything outside S both true and false. -/
theorem relevance_le {P P' : Rule α → Prop} {S : α → Prop}
    (hS : ∀ r, P r → S r.head → (∀ p ∈ r.pos, S p) ∧ ∀ n ∈ r.neg, S n)
    (hagree : ∀ r, S r.head → (P r ↔ P' r)) :
    ∀ a, S a → (WfmT P a → WfmT P' a) ∧ (WfmF P a → WfmF P' a) := by
  intro a ha
  have hc : ∀ T' F', Closed P' T' F' → Closed P (fun x => ¬S x ∨ T' x) (fun x => ¬S x ∨ F' x) := by
    intro T' F' hI
    refine ⟨fun r hr hp hn => ?_, fun U hU x hx => ?_⟩
    · by_cases hh : S r.head
      · have ⟨hpS, hnS⟩ := hS r hr hh
        refine Or.inr (hI.rules r ((hagree r hh).mp hr) (fun p h => ?_) (fun n h => ?_))
        · exact (hp p h).resolve_left (absurd (hpS p h))
        · exact (hn n h).resolve_left (absurd (hnS n h))
      · exact Or.inl hh
    · by_cases hxS : S x
      · refine Or.inr (hI.unfounded (fun y => S y ∧ U y) ?_ x ⟨hxS, hx⟩)
        intro y ⟨hyS, hy⟩ r hr hry
        have hrP : P r := (hagree r (hry ▸ hyS)).mpr hr
        have ⟨hpS, hnS⟩ := hS r hrP (hry ▸ hyS)
        rcases hU y hy r hrP hry with ⟨p, hp, hp'⟩ | ⟨n, hn, hn'⟩
        · refine Or.inl ⟨p, hp, ?_⟩
          rcases hp' with h | h
          · exact Or.inl (h.resolve_left (absurd (hpS p hp)))
          · exact Or.inr ⟨hpS p hp, h⟩
        · exact Or.inr ⟨n, hn, hn'.resolve_left (absurd (hnS n hn))⟩
      · exact Or.inl hxS
  exact ⟨fun h T' F' hI => (h _ _ (hc T' F' hI)).resolve_left (absurd ha),
    fun h T' F' hI => (h _ _ (hc T' F' hI)).resolve_left (absurd ha)⟩

/-- Relevance: two programs with the same rules for every head of S, a set that holds every atom its rules read,
give every atom of S the same value in their well-founded models. A change leaves every atom outside its cone as it was. -/
theorem relevance {P P' : Rule α → Prop} {S : α → Prop}
    (hS : ∀ r, P r → S r.head → (∀ p ∈ r.pos, S p) ∧ ∀ n ∈ r.neg, S n)
    (hagree : ∀ r, S r.head → (P r ↔ P' r)) :
    ∀ a, S a → (WfmT P a ↔ WfmT P' a) ∧ (WfmF P a ↔ WfmF P' a) := by
  have hS' : ∀ r, P' r → S r.head → (∀ p ∈ r.pos, S p) ∧ ∀ n ∈ r.neg, S n :=
    fun r hr hh => hS r ((hagree r hh).mpr hr) hh
  have hagree' : ∀ r, S r.head → (P' r ↔ P r) := fun r hh => (hagree r hh).symm
  intro a ha
  have h1 := relevance_le hS hagree a ha
  have h2 := relevance_le hS' hagree' a ha
  exact ⟨⟨h1.1, h2.1⟩, ⟨h1.2, h2.2⟩⟩

/-- On a verified verdict, every violation is false in the well-founded model of the full ground program. -/
theorem verify_wfm {E : Ext} {bad rules facts poss c} (h : verify E bad rules facts poss c = true) :
    ∀ a, bad a = true → WfmF (Full E rules facts) a :=
  fun a hb _ _ hI => verify_sound E h hI a hb

end Yen
