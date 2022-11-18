/-
Copyright (c) 2018 Mario Carneiro. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Mario Carneiro
-/
prelude
import Leanbin.Init.Meta.Tactic
import Leanbin.Init.Meta.Interactive

/-!
# Instance cache tactics

For performance reasons, Lean does not automatically update its database
of class instances during a proof. The group of tactics in this file
helps to force such updates.

-/


open Lean.Parser

open Interactive Interactive.Types

-- mathport name: «expr ?»
local postfix:1024 "?" => optional

-- mathport name: «expr *»
local postfix:1024 "*" => many

namespace Tactic

/-- Reset the instance cache for the main goal. -/
unsafe def reset_instance_cache : tactic Unit := do
  unfreeze_local_instances
  freeze_local_instances
#align tactic.reset_instance_cache tactic.reset_instance_cache

/-- Unfreeze the local instances while executing `tac` on the main goal. -/
unsafe def unfreezing {α} (tac : tactic α) : tactic α :=
  focus1 <| unfreeze_local_instances *> tac <* all_goals freeze_local_instances
#align tactic.unfreezing tactic.unfreezing

/-- Unfreeze local instances while executing `tac`,
if the passed expression is amongst the frozen instances.
-/
unsafe def unfreezing_hyp (h : expr) (tac : tactic Unit) : tactic Unit := do
  let frozen ← frozen_local_instances
  if h ∈ frozen [] then unfreezing tac else tac
#align tactic.unfreezing_hyp tactic.unfreezing_hyp

namespace Interactive

/-- `unfreezingI { tac }` executes tac while temporarily unfreezing the instance cache.
-/
unsafe def unfreezingI (tac : itactic) :=
  unfreezing tac
#align tactic.interactive.unfreezingI tactic.interactive.unfreezingI

/-- Reset the instance cache. This allows any new instances
added to the context to be used in typeclass inference. -/
unsafe def resetI :=
  reset_instance_cache
#align tactic.interactive.resetI tactic.interactive.resetI

/-- Like `revert`, but can also revert instance arguments. -/
unsafe def revertI (ids : parse ident*) : tactic Unit :=
  unfreezingI (revert ids)
#align tactic.interactive.revertI tactic.interactive.revertI

/-- Like `subst`, but can also substitute in instance arguments. -/
unsafe def substI (q : parse texpr) : tactic Unit :=
  unfreezingI (subst q)
#align tactic.interactive.substI tactic.interactive.substI

/-- Like `cases`, but can also be used with instance arguments. -/
unsafe def casesI (p : parse cases_arg_p) (q : parse with_ident_list) : tactic Unit :=
  unfreezingI (cases p q)
#align tactic.interactive.casesI tactic.interactive.casesI

/-- Like `intro`, but uses the introduced variable
in typeclass inference. -/
unsafe def introI (p : parse ident_ ?) : tactic Unit :=
  intro p >> reset_instance_cache
#align tactic.interactive.introI tactic.interactive.introI

/-- Like `intros`, but uses the introduced variable(s)
in typeclass inference. -/
unsafe def introsI (p : parse ident_*) : tactic Unit :=
  intros p >> reset_instance_cache
#align tactic.interactive.introsI tactic.interactive.introsI

/-- Used to add typeclasses to the context so that they can
be used in typeclass inference. The syntax is the same as `have`. -/
unsafe def haveI (h : parse ident ?) (q₁ : parse (tk ":" *> texpr)?) (q₂ : parse (tk ":=" *> texpr)?) : tactic Unit :=
  do
  let h ←
    match h with
      | none => get_unused_name "_inst"
      | some a => return a
  have (some h) q₁ q₂
  match q₂ with
    | none => (swap >> reset_instance_cache) >> swap
    | some p₂ => reset_instance_cache
#align tactic.interactive.haveI tactic.interactive.haveI

/-- Used to add typeclasses to the context so that they can
be used in typeclass inference. The syntax is the same as `let`. -/
unsafe def letI (h : parse ident ?) (q₁ : parse (tk ":" *> texpr)?) (q₂ : parse <| (tk ":=" *> texpr)?) : tactic Unit :=
  do
  let h ←
    match h with
      | none => get_unused_name "_inst"
      | some a => return a
  let (some h) q₁ q₂
  match q₂ with
    | none => (swap >> reset_instance_cache) >> swap
    | some p₂ => reset_instance_cache
#align tactic.interactive.letI tactic.interactive.letI

/-- Like `exact`, but uses all variables in the context
for typeclass inference. -/
unsafe def exactI (q : parse texpr) : tactic Unit :=
  reset_instance_cache >> exact q
#align tactic.interactive.exactI tactic.interactive.exactI

end Interactive

end Tactic

