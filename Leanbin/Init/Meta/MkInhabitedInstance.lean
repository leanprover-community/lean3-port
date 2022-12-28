/-
Copyright (c) 2016 Microsoft Corporation. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Leonardo de Moura

Helper tactic for showing that a type is inhabited.

! This file was ported from Lean 3 source module init.meta.mk_inhabited_instance
! leanprover-community/lean commit 855e5b74e3a52a40552e8f067169d747d48743fd
! Please do not edit these lines, except to modify the commit id
! if you have ported upstream changes.
-/
prelude
import Leanbin.Init.Meta.InteractiveBase
import Leanbin.Init.Meta.ContradictionTactic
import Leanbin.Init.Meta.ConstructorTactic
import Leanbin.Init.Meta.InjectionTactic
import Leanbin.Init.Meta.RelationTactics

namespace Tactic

open Expr Environment List

/-- Retrieve the name of the type we are building an inhabitant instance for. -/
private unsafe def get_inhabited_type_name : tactic Name :=
  (do
      let app (const n ls) t ← target >>= whnf
      when (n ≠ `inhabited) failed
      let const I ls ← return (get_app_fn t)
      return I) <|>
    fail
      "mk_inhabited_instance tactic failed, target type is expected to be of the form (inhabited ...)"
#align tactic.get_inhabited_type_name tactic.get_inhabited_type_name

/-- Try to synthesize constructor argument using type class resolution -/
private unsafe def mk_inhabited_arg : tactic Unit := do
  let tgt ← target
  let inh ← mk_app `inhabited [tgt]
  let inst ← mk_instance inh
  mk_app `inhabited.default [inst] >>= exact
#align tactic.mk_inhabited_arg tactic.mk_inhabited_arg

private unsafe def try_constructors : Nat → Nat → tactic Unit
  | 0, n => failed
  | i + 1, n =>
    (do
        constructor_idx (n - i)
        all_goals mk_inhabited_arg
        done) <|>
      try_constructors i n
#align tactic.try_constructors tactic.try_constructors

unsafe def mk_inhabited_instance : tactic Unit := do
  let I ← get_inhabited_type_name
  let env ← get_env
  let n := length (constructors_of env I)
  when (n = 0) (fail f! "mk_inhabited_instance failed, type '{I}' does not have constructors")
  constructor
  try_constructors n n <|>
      fail
        f! "mk_inhabited_instance failed, failed to build instance using all constructors of '{I}'"
#align tactic.mk_inhabited_instance tactic.mk_inhabited_instance

end Tactic

