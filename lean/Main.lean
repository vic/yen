import Ground
import Facts
import Waves
import Wfm
import Lean.Data.Json

/-!
yen-cert-check FILE: the Lean checker on a verdict that yen exports, `result.check.lean`.
FILE is JSON: { rules; facts; externals; certificate = { proved; refuted; }; }, each constant its `toJSON` key, a
variable { var; }. Lean grounds the rules itself; `verify_sound`: on exit 0 no violation is true or undefined in the
full ground program of the rules and facts, whose shape `shapeOk` checks first. Exit 1 when the verdict does not
verify, 2 on input Lean cannot decide.
yen-cert-check --change FILE: { base; staged; } from lib.stage's `lean`; the staged verdict must verify, and the
cone of the change is named (`relevance`: every other atom keeps its value).
yen-cert-check --waves FILE: { edges; layers; } from lib.batteries.lean.waves (`waves_acyclic`).
-/

open Lean Yen

instance : FromJson Yen.Term where
  fromJson? j := match j.getStr? with
    | .ok c => pure (.const c)
    | .error _ => return .var (← j.getObjValAs? String "var")

deriving instance FromJson for RuleData, Rule, Proved, Refuted, Certificate

structure WavesInput where
  edges : List (String × String)
  layers : List (List String)
deriving FromJson

-- yen-cert-check --waves FILE: { edges = [ [ from to ] ]; layers; } from lib.batteries.lean.waves
def checkWaves (path : String) : IO UInt32 := do
  match Json.parse (← IO.FS.readFile path) >>= fromJson? (α := WavesInput) with
  | .error e => IO.eprintln s!"yen-cert-check: {path}: {e}"; return 2
  | .ok w =>
    let summary := s!"{w.edges.length} edges, {w.layers.length} waves"
    if wavesOk w.edges w.layers then
      IO.println s!"verified: every node deploys after what it depends on, and the graph has no cycle ({summary})"; return 0
    let missing := (nodesOf w.edges).eraseDups.filter fun n => (waveOf w.layers n).isNone
    IO.eprintln s!"rejected: the waves do not respect the edges ({summary}); nodes in no wave (on a cycle?): {missing}"
    return 1

structure Verdict where
  rules : List RuleData
  facts : List Atom
  externals : List String
  certificate : Certificate Atom
deriving FromJson

def comparisons : List String := ["\"lt\"", "\"neq\""]

-- `lib.datalog.comparisons`: neq on any two terms; lt on two ints or two strings, false on terms of two types
def ext : Ext where
  isExt r := comparisons.contains r
  holds
    | ["\"neq\"", x, y] => x != y
    | ["\"lt\"", x, y] =>
      match Json.parse x, Json.parse y with
      | .ok (.str s), .ok (.str t) => decide (s < t)
      | .ok a, .ok b => match a.getInt?, b.getInt? with
        | .ok m, .ok n => decide (m < n)
        | _, _ => false
      | _, _ => false
    | _ => false

def isBad (a : Atom) : Bool := a.head? == some "\"bad\""

-- what may hold: rounds of grounding over the heads so far. Not trusted: `verify` checks the result covers the rules
def saturate (rules : List RuleData) : Nat → List Atom → List Atom
  | 0, poss => poss
  | n + 1, poss =>
    let next := (poss ++ (rules.flatMap (groundRule ext poss)).map (·.head)).eraseDups
    if next.length == poss.length then poss else saturate rules n next

def relOf : List Yen.Term → Option String
  | .const r :: _ => some r
  | _ => none

def groundOf (v : Verdict) : List (Rule Atom) :=
  build ext v.rules v.facts (saturate v.rules (v.facts.length + 1000) v.facts.eraseDups)

def checkVerdict (v : Verdict) : IO UInt32 := do
  let atoms := v.rules.flatMap fun R => R.head :: R.pos ++ R.neg
  let unknown := (atoms.filterMap relOf).eraseDups.filter fun r => v.externals.contains r && !comparisons.contains r
  if !unknown.isEmpty then
    IO.eprintln s!"yen-cert-check: external relations Lean cannot decide: {unknown}"; return 2
  let poss := saturate v.rules (v.facts.length + 1000) v.facts.eraseDups
  let G := build ext v.rules v.facts poss
  let c := v.certificate
  let summary := s!"{v.rules.length} rules, {v.facts.length} facts, {G.length} ground rules, {c.proved.length} proved, {c.refuted.length} refuted"
  if !shapeOk v.facts then
    IO.eprintln s!"rejected: the facts are not well formed: an id that is no scope, a scope without one kind, two parents, or a parent cycle ({summary})"; return 1
  if verify ext isBad v.rules v.facts poss c then
    IO.println s!"verified: no violation is true or undefined ({summary})"; return 0
  if !v.rules.all (safe ext) then
    IO.eprintln s!"rejected: a rule is not safe ({summary})"
  else if !covered ext v.rules G then
    IO.eprintln s!"rejected: the grounding does not cover the rules ({summary})"
  else if !check G c then
    IO.eprintln s!"rejected: the certificate does not check ({summary})"
  else
    IO.eprintln s!"rejected: violations not refuted ({summary}):"
    for a in (G.map (·.head)).eraseDups.filter fun a => isBad a && (refutedStage c a).isNone do
      IO.eprintln s!"  {a}"
  return 1

structure Change where
  base : Verdict
  staged : Verdict
deriving FromJson

-- the atoms a change can reach: the heads of the rules it changed, and every head whose rule reads one of them.
-- `relevance` (Wfm.lean): every other atom keeps its value
def cone (rules : List (Rule Atom)) : Nat → List Atom → List Atom
  | 0, s => s
  | n + 1, s =>
    let next := (s ++ (rules.filter fun r => (r.pos ++ r.neg).any s.contains).map (·.head)).eraseDups
    if next.length == s.length then s else cone rules n next

-- yen-cert-check --change FILE: { base; staged; } from lib.stage's `lean`. The staged verdict must verify
def checkChange (path : String) : IO UInt32 := do
  match Json.parse (← IO.FS.readFile path) >>= fromJson? (α := Change) with
  | .error e => IO.eprintln s!"yen-cert-check: {path}: {e}"; return 2
  | .ok ch =>
    let code ← checkVerdict ch.staged
    let Gb := groundOf ch.base
    let Gs := groundOf ch.staged
    let changed := (Gb.filter (!Gs.contains ·)) ++ (Gs.filter (!Gb.contains ·))
    let reach := cone (Gb ++ Gs) (Gb.length + Gs.length + 1) (changed.map (·.head)).eraseDups
    IO.println s!"change: {changed.length} ground rules changed; {reach.length} atoms in their cone; every other atom keeps its value (relevance)"
    for a in reach.filter isBad do
      IO.println s!"  in the cone: {a}"
    return code

def main (args : List String) : IO UInt32 := do
  if let ["--waves", path] := args then return (← checkWaves path)
  if let ["--change", path] := args then return (← checkChange path)
  let [path] := args | IO.eprintln "usage: yen-cert-check FILE.json | --waves FILE.json | --change FILE.json"; return 2
  match Json.parse (← IO.FS.readFile path) >>= fromJson? (α := Verdict) with
  | .error e => IO.eprintln s!"yen-cert-check: {path}: {e}"; return 2
  | .ok v => checkVerdict v
