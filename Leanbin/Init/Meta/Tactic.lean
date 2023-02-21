/-
Copyright (c) 2016 Microsoft Corporation. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Leonardo de Moura

! This file was ported from Lean 3 source module init.meta.tactic
! leanprover-community/mathlib commit 4a03bdeb31b3688c31d02d7ff8e0ff2e5d6174db
! Please do not edit these lines, except to modify the commit id
! if you have ported upstream changes.
-/
prelude
import Leanbin.Init.Function
import Leanbin.Init.Data.Option.Basic
import Leanbin.Init.Util
import Leanbin.Init.Control.Combinators
import Leanbin.Init.Control.Monad
import Leanbin.Init.Control.Alternative
import Leanbin.Init.Control.MonadFail
import Leanbin.Init.Data.Nat.Div
import Leanbin.Init.Meta.Exceptional
import Leanbin.Init.Meta.Format
import Leanbin.Init.Meta.Environment
import Leanbin.Init.Meta.Pexpr
import Leanbin.Init.Data.Repr
import Leanbin.Init.Data.String.Basic
import Leanbin.Init.Meta.InteractionMonad
import Leanbin.Init.Classical

open Native

unsafe axiom tactic_state : Type
#align tactic_state tactic_state

universe u v

namespace TacticState

unsafe axiom env : tactic_state → environment
#align tactic_state.env tactic_state.env

/-- Format the given tactic state. If `target_lhs_only` is true and the target
    is of the form `lhs ~ rhs`, where `~` is a simplification relation,
    then only the `lhs` is displayed.

    Remark: the parameter `target_lhs_only` is a temporary hack used to implement
    the `conv` monad. It will be removed in the future. -/
unsafe axiom to_format (s : tactic_state) (target_lhs_only : Bool := false) : format
#align tactic_state.to_format tactic_state.to_format

/-- Format expression with respect to the main goal in the tactic state.
   If the tactic state does not contain any goals, then format expression
   using an empty local context. -/
unsafe axiom format_expr : tactic_state → expr → format
#align tactic_state.format_expr tactic_state.format_expr

unsafe axiom get_options : tactic_state → options
#align tactic_state.get_options tactic_state.get_options

unsafe axiom set_options : tactic_state → options → tactic_state
#align tactic_state.set_options tactic_state.set_options

end TacticState

unsafe instance : has_to_format tactic_state :=
  ⟨tactic_state.to_format⟩

unsafe instance : ToString tactic_state :=
  ⟨fun s => (to_fmt s).toString s.get_options⟩

/-- `tactic` is the monad for building tactics.
    You use this to:
    - View and modify the local goals and hypotheses in the prover's state.
    - Invoke type checking and elaboration of terms.
    - View and modify the environment.
    - Build new tactics out of existing ones such as `simp` and `rewrite`.
-/
@[reducible]
unsafe def tactic :=
  interaction_monad tactic_state
#align tactic tactic

@[reducible]
unsafe def tactic_result :=
  interaction_monad.result tactic_state
#align tactic_result tactic_result

namespace Tactic

export
  InteractionMonad (result result.success result.exception result.cases_on result_to_string mk_exception silent_fail orelse' bracket)

/-- Cause the tactic to fail with no error message. -/
unsafe def failed {α : Type} : tactic α :=
  interaction_monad.failed
#align tactic.failed tactic.failed

unsafe def fail {α : Type u} {β : Type v} [has_to_format β] (msg : β) : tactic α :=
  interaction_monad.fail msg
#align tactic.fail tactic.fail

end Tactic

namespace TacticResult

export InteractionMonad.Result ()

end TacticResult

open Tactic

open TacticResult

-- mathport name: «expr >>=[tactic] »
infixl:2 " >>=[tactic] " => interaction_monad_bind

-- mathport name: «expr >>[tactic] »
infixl:2 " >>[tactic] " => interaction_monad_seq

unsafe instance : Alternative tactic :=
  { interaction_monad.monad with
    failure := @interaction_monad.failed _
    orelse := @interaction_monad_orelse _ }

unsafe def tactic.up.{u₁, u₂} {α : Type u₂} (t : tactic α) : tactic (ULift.{u₁} α) := fun s =>
  match t s with
  | success a s' => success (ULift.up a) s'
  | exception t ref s => exception t ref s
#align tactic.up tactic.up

unsafe def tactic.down.{u₁, u₂} {α : Type u₂} (t : tactic (ULift.{u₁} α)) : tactic α := fun s =>
  match t s with
  | success (ULift.up a) s' => success a s'
  | exception t ref s => exception t ref s
#align tactic.down tactic.down

namespace Interactive

/-- Typeclass for custom interaction monads, which provides
    the information required to convert an interactive-mode
    construction to a `tactic` which can actually be executed.

    Given a `[monad m]`, `execute_with` explains how to turn a `begin ... end`
    block, or a `by ...` statement into a `tactic α` which can actually be
    executed. The `inhabited` first argument facilitates the passing of an
    optional configuration parameter `config`, using the syntax:
    ```
    begin [custom_monad] with config,
        ...
    end
    ```
-/
unsafe class executor (m : Type → Type u) [Monad m] where
  config_type : Type
  [Inhabited : Inhabited config_type]
  execute_with : config_type → m Unit → tactic Unit
#align interactive.executor interactive.executor

attribute [inline] executor.execute_with

@[inline]
unsafe def executor.execute_explicit (m : Type → Type u) [Monad m] [e : executor m] :
    m Unit → tactic Unit :=
  executor.execute_with e.Inhabited.default
#align interactive.executor.execute_explicit interactive.executor.execute_explicit

@[inline]
unsafe def executor.execute_with_explicit (m : Type → Type u) [Monad m] [executor m] :
    executor.config_type m → m Unit → tactic Unit :=
  executor.execute_with
#align interactive.executor.execute_with_explicit interactive.executor.execute_with_explicit

/-- Default `executor` instance for `tactic`s themselves -/
unsafe instance executor_tactic : executor tactic
    where
  config_type := Unit
  Inhabited := ⟨()⟩
  execute_with _ := id
#align interactive.executor_tactic interactive.executor_tactic

end Interactive

namespace Tactic

open InteractionMonad.Result

variable {α : Type u}

/-- Does nothing. -/
unsafe def skip : tactic Unit :=
  success ()
#align tactic.skip tactic.skip

/-- `try_core t` acts like `t`, but succeeds even if `t` fails. It returns the
result of `t` if `t` succeeded and `none` otherwise.
-/
unsafe def try_core (t : tactic α) : tactic (Option α) := fun s =>
  match t s with
  | exception _ _ _ => success none s
  | success a s' => success (some a) s'
#align tactic.try_core tactic.try_core

/-- `try t` acts like `t`, but succeeds even if `t` fails.
-/
unsafe def try (t : tactic α) : tactic Unit := fun s =>
  match t s with
  | exception _ _ _ => success () s
  | success _ s' => success () s'
#align tactic.try tactic.try

unsafe def try_lst : List (tactic Unit) → tactic Unit
  | [] => failed
  | tac :: tacs => fun s =>
    match tac s with
    | success _ s' => try (try_lst tacs) s'
    | exception e p s' =>
      match try_lst tacs s' with
      | exception _ _ _ => exception e p s'
      | r => r
#align tactic.try_lst tactic.try_lst

/-- `fail_if_success t` acts like `t`, but succeeds if `t` fails and fails if `t`
succeeds. Changes made by `t` to the `tactic_state` are preserved only if `t`
succeeds.
-/
unsafe def fail_if_success {α : Type u} (t : tactic α) : tactic Unit := fun s =>
  match t s with
  | success a s => mk_exception "fail_if_success combinator failed, given tactic succeeded" none s
  | exception _ _ _ => success () s
#align tactic.fail_if_success tactic.fail_if_success

/-- `success_if_fail t` acts like `t`, but succeeds if `t` fails and fails if `t`
succeeds. Changes made by `t` to the `tactic_state` are preserved only if `t`
succeeds.
-/
unsafe def success_if_fail {α : Type u} (t : tactic α) : tactic Unit := fun s =>
  match t s with
  | success a s => mk_exception "success_if_fail combinator failed, given tactic succeeded" none s
  | exception _ _ _ => success () s
#align tactic.success_if_fail tactic.success_if_fail

open Nat

/-- `iterate_at_most n t` iterates `t` `n` times or until `t` fails, returning the
result of each successful iteration.
-/
unsafe def iterate_at_most : Nat → tactic α → tactic (List α)
  | 0, t => pure []
  | n + 1, t => do
    let some a ← try_core t |
      pure []
    let as ← iterate_at_most n t
    pure <| a :: as
#align tactic.iterate_at_most tactic.iterate_at_most

/-- `iterate_at_most' n t` repeats `t` `n` times or until `t` fails.
-/
unsafe def iterate_at_most' : Nat → tactic Unit → tactic Unit
  | 0, t => skip
  | succ n, t => do
    let some _ ← try_core t |
      skip
    iterate_at_most' n t
#align tactic.iterate_at_most' tactic.iterate_at_most'

/-- `iterate_exactly n t` iterates `t` `n` times, returning the result of
each iteration. If any iteration fails, the whole tactic fails.
-/
unsafe def iterate_exactly : Nat → tactic α → tactic (List α)
  | 0, t => pure []
  | n + 1, t => do
    let a ← t
    let as ← iterate_exactly n t
    pure <| a :: as
#align tactic.iterate_exactly tactic.iterate_exactly

/-- `iterate_exactly' n t` executes `t` `n` times. If any iteration fails, the whole
tactic fails.
-/
unsafe def iterate_exactly' : Nat → tactic Unit → tactic Unit
  | 0, t => skip
  | n + 1, t => t *> iterate_exactly' n t
#align tactic.iterate_exactly' tactic.iterate_exactly'

/-- `iterate t` repeats `t` 100.000 times or until `t` fails, returning the
result of each iteration.
-/
unsafe def iterate : tactic α → tactic (List α) :=
  iterate_at_most 100000
#align tactic.iterate tactic.iterate

/-- `iterate' t` repeats `t` 100.000 times or until `t` fails.
-/
unsafe def iterate' : tactic Unit → tactic Unit :=
  iterate_at_most' 100000
#align tactic.iterate' tactic.iterate'

unsafe def returnopt (e : Option α) : tactic α := fun s =>
  match e with
  | some a => success a s
  | none => mk_exception "failed" none s
#align tactic.returnopt tactic.returnopt

unsafe instance opt_to_tac : Coe (Option α) (tactic α) :=
  ⟨returnopt⟩
#align tactic.opt_to_tac tactic.opt_to_tac

/-- Decorate t's exceptions with msg. -/
unsafe def decorate_ex (msg : format) (t : tactic α) : tactic α := fun s =>
  result.cases_on (t s) success fun opt_thunk =>
    match opt_thunk with
    | some e => exception (some fun u => msg ++ format.nest 2 (format.line ++ e u))
    | none => exception none
#align tactic.decorate_ex tactic.decorate_ex

/-- Set the tactic_state. -/
@[inline]
unsafe def write (s' : tactic_state) : tactic Unit := fun s => success () s'
#align tactic.write tactic.write

/-- Get the tactic_state. -/
@[inline]
unsafe def read : tactic tactic_state := fun s => success s s
#align tactic.read tactic.read

/-- `capture t` acts like `t`, but succeeds with a result containing either the returned value
or the exception.
Changes made by `t` to the `tactic_state` are preserved in both cases.

The result can be used to inspect the error message, or passed to `unwrap` to rethrow the
failure later.
-/
unsafe def capture (t : tactic α) : tactic (tactic_result α) := fun s =>
  match t s with
  | success r s' => success (success r s') s'
  | exception f p s' => success (exception f p s') s'
#align tactic.capture tactic.capture

/-- `unwrap r` unwraps a result previously obtained using `capture`.

If the previous result was a success, this produces its wrapped value.
If the previous result was an exception, this "rethrows" the exception as if it came
from where it originated.

`do r ← capture t, unwrap r` is identical to `t`, but allows for intermediate tactics to be inserted.
-/
unsafe def unwrap {α : Type _} (t : tactic_result α) : tactic α :=
  match t with
  | success r s' => return r
  | e => fun s => e
#align tactic.unwrap tactic.unwrap

/-- `resume r` continues execution from a result previously obtained using `capture`.

This is like `unwrap`, but the `tactic_state` is rolled back to point of capture even upon success.
-/
unsafe def resume {α : Type _} (t : tactic_result α) : tactic α := fun s => t
#align tactic.resume tactic.resume

unsafe def get_options : tactic options := do
  let s ← read
  return s
#align tactic.get_options tactic.get_options

unsafe def set_options (o : options) : tactic Unit := do
  let s ← read
  write (s o)
#align tactic.set_options tactic.set_options

unsafe def save_options {α : Type} (t : tactic α) : tactic α := do
  let o ← get_options
  let a ← t
  set_options o
  return a
#align tactic.save_options tactic.save_options

unsafe def returnex {α : Type} (e : exceptional α) : tactic α := fun s =>
  match e with
  | exceptional.success a => success a s
  | exceptional.exception f =>
    match get_options s with
    | success opt _ => exception (some fun u => f opt) none s
    | exception _ _ _ => exception (some fun u => f options.mk) none s
#align tactic.returnex tactic.returnex

unsafe instance ex_to_tac {α : Type} : Coe (exceptional α) (tactic α) :=
  ⟨returnex⟩
#align tactic.ex_to_tac tactic.ex_to_tac

end Tactic

unsafe def tactic_format_expr (e : expr) : tactic format := do
  let s ← tactic.read
  return (tactic_state.format_expr s e)
#align tactic_format_expr tactic_format_expr

unsafe class has_to_tactic_format (α : Type u) where
  to_tactic_format : α → tactic format
#align has_to_tactic_format has_to_tactic_format

unsafe instance : has_to_tactic_format expr :=
  ⟨tactic_format_expr⟩

unsafe def tactic.pp {α : Type u} [has_to_tactic_format α] : α → tactic format :=
  has_to_tactic_format.to_tactic_format
#align tactic.pp tactic.pp

open Tactic Format

unsafe instance {α : Type u} [has_to_tactic_format α] : has_to_tactic_format (List α) :=
  ⟨fun l => to_fmt <$> l.mapM pp⟩

unsafe instance (α : Type u) (β : Type v) [has_to_tactic_format α] [has_to_tactic_format β] :
    has_to_tactic_format (α × β) :=
  ⟨fun ⟨a, b⟩ => to_fmt <$> (Prod.mk <$> pp a <*> pp b)⟩

unsafe def option_to_tactic_format {α : Type u} [has_to_tactic_format α] : Option α → tactic format
  | some a => do
    let fa ← pp a
    return (to_fmt "(some " ++ fa ++ ")")
  | none => return "none"
#align option_to_tactic_format option_to_tactic_format

unsafe instance {α : Type u} [has_to_tactic_format α] : has_to_tactic_format (Option α) :=
  ⟨option_to_tactic_format⟩

unsafe instance {α} (a : α) : has_to_tactic_format (reflected _ a) :=
  ⟨fun h => pp h.to_expr⟩

unsafe instance (priority := 10) has_to_format_to_has_to_tactic_format (α : Type)
    [has_to_format α] : has_to_tactic_format α :=
  ⟨(fun x => return x) ∘ to_fmt⟩
#align has_to_format_to_has_to_tactic_format has_to_format_to_has_to_tactic_format

namespace Tactic

open TacticState

unsafe def get_env : tactic environment := do
  let s ← read
  return <| env s
#align tactic.get_env tactic.get_env

unsafe def get_decl (n : Name) : tactic declaration := do
  let s ← read
  (env s).get n
#align tactic.get_decl tactic.get_decl

unsafe axiom get_trace_msg_pos : tactic Pos
#align tactic.get_trace_msg_pos tactic.get_trace_msg_pos

unsafe def trace {α : Type u} [has_to_tactic_format α] (a : α) : tactic Unit := do
  let fmt ← pp a
  return <| _root_.trace_fmt fmt fun u => ()
#align tactic.trace tactic.trace

unsafe def trace_call_stack : tactic Unit := fun state => traceCallStack (success () StateM)
#align tactic.trace_call_stack tactic.trace_call_stack

unsafe def timetac {α : Type u} (desc : String) (t : Thunk (tactic α)) : tactic α := fun s =>
  timeit desc (t () s)
#align tactic.timetac tactic.timetac

unsafe def trace_state : tactic Unit := do
  let s ← read
  trace <| to_fmt s
#align tactic.trace_state tactic.trace_state

/--
A parameter representing how aggressively definitions should be unfolded when trying to decide if two terms match, unify or are definitionally equal.
By default, theorem declarations are never unfolded.
- `all` will unfold everything, including macros and theorems. Except projection macros.
- `semireducible` will unfold everything except theorems and definitions tagged as irreducible.
- `instances` will unfold all class instance definitions and definitions tagged with reducible.
- `reducible` will only unfold definitions tagged with the `reducible` attribute.
- `none` will never unfold anything.
[NOTE] You are not allowed to tag a definition with more than one of `reducible`, `irreducible`, `semireducible` attributes.
[NOTE] there is a config flag `m_unfold_lemmas`that will make it unfold theorems.
 -/
inductive Transparency
  | all
  | semireducible
  | instances
  | reducible
  | none
#align tactic.transparency Tactic.Transparency

export Transparency (reducible semireducible)

/-- (eval_expr α e) evaluates 'e' IF 'e' has type 'α'. -/
unsafe axiom eval_expr (α : Type u) [reflected _ α] : expr → tactic α
#align tactic.eval_expr tactic.eval_expr

/-- Return the partial term/proof constructed so far. Note that the resultant expression
   may contain variables that are not declarate in the current main goal. -/
unsafe axiom result : tactic expr
#align tactic.result tactic.result

/-- Display the partial term/proof constructed so far. This tactic is *not* equivalent to
   `do { r ← result, s ← read, return (format_expr s r) }` because this one will format the result with respect
   to the current goal, and trace_result will do it with respect to the initial goal. -/
unsafe axiom format_result : tactic format
#align tactic.format_result tactic.format_result

/-- Return target type of the main goal. Fail if tactic_state does not have any goal left. -/
unsafe axiom target : tactic expr
#align tactic.target tactic.target

unsafe axiom intro_core : Name → tactic expr
#align tactic.intro_core tactic.intro_core

unsafe axiom intron : Nat → tactic Unit
#align tactic.intron tactic.intron

/--
Clear the given local constant. The tactic fails if the given expression is not a local constant. -/
unsafe axiom clear : expr → tactic Unit
#align tactic.clear tactic.clear

/--
`revert_lst : list expr → tactic nat` is the reverse of `intron`. It takes a local constant `c` and puts it back as bound by a `pi` or `elet` of the main target.
If there are other local constants that depend on `c`, these are also reverted. Because of this, the `nat` that is returned is the actual number of reverted local constants.
Example: with `x : ℕ, h : P(x) ⊢ T(x)`, `revert_lst [x]` returns `2` and produces the state ` ⊢ Π x, P(x) → T(x)`.
 -/
unsafe axiom revert_lst : List expr → tactic Nat
#align tactic.revert_lst tactic.revert_lst

/-- Return `e` in weak head normal form with respect to the given transparency setting.
    If `unfold_ginductive` is `tt`, then nested and/or mutually recursive inductive datatype constructors
    and types are unfolded. Recall that nested and mutually recursive inductive datatype declarations
    are compiled into primitive datatypes accepted by the Kernel. -/
unsafe axiom whnf (e : expr) (md := semireducible) (unfold_ginductive := true) : tactic expr
#align tactic.whnf tactic.whnf

/--
(head) eta expand the given expression. `f : α → β` head-eta-expands to `λ a, f a`. If `f` isn't a function then it just returns `f`.  -/
unsafe axiom head_eta_expand : expr → tactic expr
#align tactic.head_eta_expand tactic.head_eta_expand

/-- (head) beta reduction. `(λ x, B) c` reduces to `B[x/c]`. -/
unsafe axiom head_beta : expr → tactic expr
#align tactic.head_beta tactic.head_beta

/--
(head) zeta reduction. Reduction of let bindings at the head of the expression. `let x : a := b in c` reduces to `c[x/b]`. -/
unsafe axiom head_zeta : expr → tactic expr
#align tactic.head_zeta tactic.head_zeta

/-- Zeta reduction. Reduction of let bindings. `let x : a := b in c` reduces to `c[x/b]`. -/
unsafe axiom zeta : expr → tactic expr
#align tactic.zeta tactic.zeta

/-- (head) eta reduction. `(λ x, f x)` reduces to `f`. -/
unsafe axiom head_eta : expr → tactic expr
#align tactic.head_eta tactic.head_eta

/-- Succeeds if `t` and `s` can be unified using the given transparency setting. -/
unsafe axiom unify (t s : expr) (md := semireducible) (approx := false) : tactic Unit
#align tactic.unify tactic.unify

/-- Similar to `unify`, but it treats metavariables as constants. -/
unsafe axiom is_def_eq (t s : expr) (md := semireducible) (approx := false) : tactic Unit
#align tactic.is_def_eq tactic.is_def_eq

/-- Infer the type of the given expression.
   Remark: transparency does not affect type inference -/
unsafe axiom infer_type : expr → tactic expr
#align tactic.infer_type tactic.infer_type

/-- Get the `local_const` expr for the given `name`. -/
unsafe axiom get_local : Name → tactic expr
#align tactic.get_local tactic.get_local

/-- Resolve a name using the current local context, environment, aliases, etc. -/
unsafe axiom resolve_name : Name → tactic pexpr
#align tactic.resolve_name tactic.resolve_name

/-- Return the hypothesis in the main goal. Fail if tactic_state does not have any goal left. -/
unsafe axiom local_context : tactic (List expr)
#align tactic.local_context tactic.local_context

/-- Get a fresh name that is guaranteed to not be in use in the local context.
    If `n` is provided and `n` is not in use, then `n` is returned.
    Otherwise a number `i` is appended to give `"n_i"`.
-/
unsafe axiom get_unused_name (n : Name := `_x) (i : Option Nat := none) : tactic Name
#align tactic.get_unused_name tactic.get_unused_name

/-- Helper tactic for creating simple applications where some arguments are inferred using
    type inference.

    Example, given
    ```
        rel.{l_1 l_2} : Pi (α : Type.{l_1}) (β : α -> Type.{l_2}), (Pi x : α, β x) -> (Pi x : α, β x) -> , Prop
        nat     : Type
        real    : Type
        vec.{l} : Pi (α : Type l) (n : nat), Type.{l1}
        f g     : Pi (n : nat), vec real n
    ```
    then
    ```
    mk_app_core semireducible "rel" [f, g]
    ```
    returns the application
    ```
    rel.{1 2} nat (fun n : nat, vec real n) f g
    ```

    The unification constraints due to type inference are solved using the transparency `md`.
-/
unsafe axiom mk_app (fn : Name) (args : List expr) (md := semireducible) : tactic expr
#align tactic.mk_app tactic.mk_app

/-- Similar to `mk_app`, but allows to specify which arguments are explicit/implicit.
   Example, given `(a b : nat)` then
   ```
   mk_mapp "ite" [some (a > b), none, none, some a, some b]
   ```
   returns the application
   ```
   @ite.{1} nat (a > b) (nat.decidable_gt a b) a b
   ```
-/
unsafe axiom mk_mapp (fn : Name) (args : List (Option expr)) (md := semireducible) : tactic expr
#align tactic.mk_mapp tactic.mk_mapp

/-- (mk_congr_arg h₁ h₂) is a more efficient version of (mk_app `congr_arg [h₁, h₂]) -/
unsafe axiom mk_congr_arg : expr → expr → tactic expr
#align tactic.mk_congr_arg tactic.mk_congr_arg

/-- (mk_congr_fun h₁ h₂) is a more efficient version of (mk_app `congr_fun [h₁, h₂]) -/
unsafe axiom mk_congr_fun : expr → expr → tactic expr
#align tactic.mk_congr_fun tactic.mk_congr_fun

/-- (mk_congr h₁ h₂) is a more efficient version of (mk_app `congr [h₁, h₂]) -/
unsafe axiom mk_congr : expr → expr → tactic expr
#align tactic.mk_congr tactic.mk_congr

/-- (mk_eq_refl h) is a more efficient version of (mk_app `eq.refl [h]) -/
unsafe axiom mk_eq_refl : expr → tactic expr
#align tactic.mk_eq_refl tactic.mk_eq_refl

/-- (mk_eq_symm h) is a more efficient version of (mk_app `eq.symm [h]) -/
unsafe axiom mk_eq_symm : expr → tactic expr
#align tactic.mk_eq_symm tactic.mk_eq_symm

/-- (mk_eq_trans h₁ h₂) is a more efficient version of (mk_app `eq.trans [h₁, h₂]) -/
unsafe axiom mk_eq_trans : expr → expr → tactic expr
#align tactic.mk_eq_trans tactic.mk_eq_trans

/-- (mk_eq_mp h₁ h₂) is a more efficient version of (mk_app `eq.mp [h₁, h₂]) -/
unsafe axiom mk_eq_mp : expr → expr → tactic expr
#align tactic.mk_eq_mp tactic.mk_eq_mp

/-- (mk_eq_mpr h₁ h₂) is a more efficient version of (mk_app `eq.mpr [h₁, h₂]) -/
unsafe axiom mk_eq_mpr : expr → expr → tactic expr
#align tactic.mk_eq_mpr tactic.mk_eq_mpr

/-- Given a local constant t, if t has type (lhs = rhs) apply substitution.
   Otherwise, try to find a local constant that has type of the form (t = t') or (t' = t).
   The tactic fails if the given expression is not a local constant. -/
unsafe axiom subst_core : expr → tactic Unit
#align tactic.subst_core tactic.subst_core

/-- Close the current goal using `e`. Fail if the type of `e` is not definitionally equal to
    the target type. -/
unsafe axiom exact (e : expr) (md := semireducible) : tactic Unit
#align tactic.exact tactic.exact

/-- Elaborate the given quoted expression with respect to the current main goal.
    Note that this means that any implicit arguments for the given `pexpr` will be applied with fresh metavariables.
    If `allow_mvars` is tt, then metavariables are tolerated and become new goals if `subgoals` is tt. -/
unsafe axiom to_expr (q : pexpr) (allow_mvars := true) (subgoals := true) : tactic expr
#align tactic.to_expr tactic.to_expr

/-- Return true if the given expression is a type class. -/
unsafe axiom is_class : expr → tactic Bool
#align tactic.is_class tactic.is_class

/-- Try to create an instance of the given type class. -/
unsafe axiom mk_instance : expr → tactic expr
#align tactic.mk_instance tactic.mk_instance

/-- Change the target of the main goal.
   The input expression must be definitionally equal to the current target.
   If `check` is `ff`, then the tactic does not check whether `e`
   is definitionally equal to the current target. If it is not,
   then the error will only be detected by the kernel type checker. -/
unsafe axiom change (e : expr) (check : Bool := true) : tactic Unit
#align tactic.change tactic.change

/-- `assert_core H T`, adds a new goal for T, and change target to `T -> target`. -/
unsafe axiom assert_core : Name → expr → tactic Unit
#align tactic.assert_core tactic.assert_core

/-- `assertv_core H T P`, change target to (T -> target) if P has type T. -/
unsafe axiom assertv_core : Name → expr → expr → tactic Unit
#align tactic.assertv_core tactic.assertv_core

/--
`define_core H T`, adds a new goal for T, and change target to  `let H : T := ?M in target` in the current goal. -/
unsafe axiom define_core : Name → expr → tactic Unit
#align tactic.define_core tactic.define_core

/-- `definev_core H T P`, change target to `let H : T := P in target` if P has type T. -/
unsafe axiom definev_core : Name → expr → expr → tactic Unit
#align tactic.definev_core tactic.definev_core

/--
Rotate goals to the left. That is, `rotate_left 1` takes the main goal and puts it to the back of the subgoal list. -/
unsafe axiom rotate_left : Nat → tactic Unit
#align tactic.rotate_left tactic.rotate_left

/-- Gets a list of metavariables, one for each goal. -/
unsafe axiom get_goals : tactic (List expr)
#align tactic.get_goals tactic.get_goals

/--
Replace the current list of goals with the given one. Each expr in the list should be a metavariable. Any assigned metavariables will be ignored.-/
unsafe axiom set_goals : List expr → tactic Unit
#align tactic.set_goals tactic.set_goals

/-- Convenience function for creating ` for proofs. -/
unsafe def mk_tagged_proof (prop : expr) (pr : expr) (tag : Name) : expr :=
  expr.mk_app (expr.const `` id_tag []) [expr.const tag [], prop, pr]
#align tactic.mk_tagged_proof tactic.mk_tagged_proof

/-- How to order the new goals made from an `apply` tactic.
Supposing we were applying `e : ∀ (a:α) (p : P(a)), Q`
- `non_dep_first` would produce goals `⊢ P(?m)`, `⊢ α`. It puts the P goal at the front because none of the arguments after `p` in `e` depend on `p`. It doesn't matter what the result `Q` depends on.
- `non_dep_only` would produce goal `⊢ P(?m)`.
- `all` would produce goals `⊢ α`, `⊢ P(?m)`.
-/
inductive NewGoals
  | non_dep_first
  | non_dep_only
  | all
#align tactic.new_goals Tactic.NewGoals

/-- Configuration options for the `apply` tactic.
- `md` sets how aggressively definitions are unfolded.
- `new_goals` is the strategy for ordering new goals.
- `instances` if `tt`, then `apply` tries to synthesize unresolved `[...]` arguments using type class resolution.
- `auto_param` if `tt`, then `apply` tries to synthesize unresolved `(h : p . tac_id)` arguments using tactic `tac_id`.
- `opt_param` if `tt`, then `apply` tries to synthesize unresolved `(a : t := v)` arguments by setting them to `v`.
- `unify` if `tt`, then `apply` is free to assign existing metavariables in the goal when solving unification constraints.
   For example, in the goal `|- ?x < succ 0`, the tactic `apply succ_lt_succ` succeeds with the default configuration,
   but `apply_with succ_lt_succ {unify := ff}` doesn't since it would require Lean to assign `?x` to `succ ?y` where
   `?y` is a fresh metavariable.
-/
structure ApplyCfg where
  md := semireducible
  approx := true
  NewGoals := NewGoals.non_dep_first
  instances := true
  autoParamₓ := true
  optParam := true
  unify := true
#align tactic.apply_cfg Tactic.ApplyCfg

/--
Apply the expression `e` to the main goal, the unification is performed using the transparency mode in `cfg`.
    Supposing `e : Π (a₁:α₁) ... (aₙ:αₙ), P(a₁,...,aₙ)` and the target is `Q`, `apply` will attempt to unify `Q` with `P(?a₁,...?aₙ)`.
    All of the metavariables that are not assigned are added as new metavariables.
    If `cfg.approx` is `tt`, then fallback to first-order unification, and approximate context during unification.
    `cfg.new_goals` specifies which unassigned metavariables become new goals, and their order.
    If `cfg.instances` is `tt`, then use type class resolution to instantiate unassigned meta-variables.
    The fields `cfg.auto_param` and `cfg.opt_param` are ignored by this tactic (See `tactic.apply`).
    It returns a list of all introduced meta variables and the parameter name associated with them, even the assigned ones. -/
unsafe axiom apply_core (e : expr) (cfg : ApplyCfg := { }) : tactic (List (Name × expr))
#align tactic.apply_core tactic.apply_core

/-- Create a fresh meta universe variable. -/
unsafe axiom mk_meta_univ : tactic level
#align tactic.mk_meta_univ tactic.mk_meta_univ

/-- Create a fresh meta-variable with the given type.
   The scope of the new meta-variable is the local context of the main goal. -/
unsafe axiom mk_meta_var : expr → tactic expr
#align tactic.mk_meta_var tactic.mk_meta_var

/-- Return the value assigned to the given universe meta-variable.
   Fail if argument is not an universe meta-variable or if it is not assigned. -/
unsafe axiom get_univ_assignment : level → tactic level
#align tactic.get_univ_assignment tactic.get_univ_assignment

/-- Return the value assigned to the given meta-variable.
   Fail if argument is not a meta-variable or if it is not assigned. -/
unsafe axiom get_assignment : expr → tactic expr
#align tactic.get_assignment tactic.get_assignment

/-- Return true if the given meta-variable is assigned.
    Fail if argument is not a meta-variable. -/
unsafe axiom is_assigned : expr → tactic Bool
#align tactic.is_assigned tactic.is_assigned

/--
Make a name that is guaranteed to be unique. Eg `_fresh.1001.4667`. These will be different for each run of the tactic.  -/
unsafe axiom mk_fresh_name : tactic Name
#align tactic.mk_fresh_name tactic.mk_fresh_name

/-- Induction on `h` using recursor `rec`, names for the new hypotheses
   are retrieved from `ns`. If `ns` does not have sufficient names, then use the internal binder names
   in the recursor.
   It returns for each new goal the name of the constructor (if `rec_name` is a builtin recursor),
   a list of new hypotheses, and a list of substitutions for hypotheses
   depending on `h`. The substitutions map internal names to their replacement terms. If the
   replacement is again a hypothesis the user name stays the same. The internal names are only valid
   in the original goal, not in the type context of the new goal.
   Remark: if `rec_name` is not a builtin recursor, we use parameter names of `rec_name` instead of
   constructor names.

   If `rec` is none, then the type of `h` is inferred, if it is of the form `C ...`, tactic uses `C.rec` -/
unsafe axiom induction (h : expr) (ns : List Name := []) (rec : Option Name := none)
    (md := semireducible) : tactic (List (Name × List expr × List (Name × expr)))
#align tactic.induction tactic.induction

/-- Apply `cases_on` recursor, names for the new hypotheses are retrieved from `ns`.
   `h` must be a local constant. It returns for each new goal the name of the constructor, a list of new hypotheses, and a list of
   substitutions for hypotheses depending on `h`. The number of new goals may be smaller than the
   number of constructors. Some goals may be discarded when the indices to not match.
   See `induction` for information on the list of substitutions.

   The `cases` tactic is implemented using this one, and it relaxes the restriction of `h`.

   Note: There is one "new hypothesis" for every constructor argument. These are
   usually local constants, but due to dependent pattern matching, they can also
   be arbitrary terms. -/
unsafe axiom cases_core (h : expr) (ns : List Name := []) (md := semireducible) :
    tactic (List (Name × List expr × List (Name × expr)))
#align tactic.cases_core tactic.cases_core

/-- Similar to cases tactic, but does not revert/intro/clear hypotheses. -/
unsafe axiom destruct (e : expr) (md := semireducible) : tactic Unit
#align tactic.destruct tactic.destruct

/-- Generalizes the target with respect to `e`.  -/
unsafe axiom generalize (e : expr) (n : Name := `_x) (md := semireducible) : tactic Unit
#align tactic.generalize tactic.generalize

/-- instantiate assigned metavariables in the given expression -/
unsafe axiom instantiate_mvars : expr → tactic expr
#align tactic.instantiate_mvars tactic.instantiate_mvars

/-- Add the given declaration to the environment -/
unsafe axiom add_decl : declaration → tactic Unit
#align tactic.add_decl tactic.add_decl

/-- Changes the environment to the `new_env`.
The new environment does not need to be a descendant of the old one.
Use with care.
-/
unsafe axiom set_env_core : environment → tactic Unit
#align tactic.set_env_core tactic.set_env_core

/--
Changes the environment to the `new_env`. `new_env` needs to be a descendant from the current environment. -/
unsafe axiom set_env : environment → tactic Unit
#align tactic.set_env tactic.set_env

/-- `doc_string env d k` returns the doc string for `d` (if available) -/
unsafe axiom doc_string : Name → tactic String
#align tactic.doc_string tactic.doc_string

/-- Set the docstring for the given declaration. -/
unsafe axiom add_doc_string : Name → String → tactic Unit
#align tactic.add_doc_string tactic.add_doc_string

/--
Create an auxiliary definition with name `c` where `type` and `value` may contain local constants and
meta-variables. This function collects all dependencies (universe parameters, universe metavariables,
local constants (aka hypotheses) and metavariables).
It updates the environment in the tactic_state, and returns an expression of the form

          (c.{l_1 ... l_n} a_1 ... a_m)

where l_i's and a_j's are the collected dependencies.
-/
unsafe axiom add_aux_decl (c : Name) (type : expr) (val : expr) (is_lemma : Bool) : tactic expr
#align tactic.add_aux_decl tactic.add_aux_decl

/--
Returns a list of all top-level (`/-! ... -/`) docstrings in the active module and imported ones.
The returned object is a list of modules, indexed by `(some filename)` for imported modules
and `none` for the active one, where each module in the list is paired with a list
of `(position_in_file, docstring)` pairs. -/
unsafe axiom olean_doc_strings : tactic (List (Option String × List (Pos × String)))
#align tactic.olean_doc_strings tactic.olean_doc_strings

/-- Returns a list of docstrings in the active module. An entry in the list can be either:
- a top-level (`/-! ... -/`) docstring, represented as `(none, docstring)`
- a declaration-specific (`/-- ... -/`) docstring, represented as `(some decl_name, docstring)` -/
unsafe def module_doc_strings : tactic (List (Option Name × String)) := do
  let mod_docs
    ←-- Obtain a list of top-level docs in current module.
      olean_doc_strings
  let mod_docs : List (List (Option Name × String)) :=
    mod_docs.filterMap fun d =>
      if d.1.isNone then some (d.2.map fun pos_doc => ⟨none, pos_doc.2⟩) else none
  let mod_docs := mod_docs.join
  let e
    ←-- Obtain list of declarations in current module.
      get_env
  let decls :=
    environment.fold e ([] : List Name) fun d acc =>
      let n := d.to_name
      if (environment.decl_olean e n).isNone then n :: Acc else Acc
  let decls
    ←-- Map declarations to those which have docstrings.
          decls.foldlM
        (fun a n => (doc_string n >>= fun doc => pure <| (some n, doc) :: a) <|> pure a) []
  pure (mod_docs ++ decls)
#align tactic.module_doc_strings tactic.module_doc_strings

/-- Set attribute `attr_name` for constant `c_name` with the given priority.
   If the priority is none, then use default -/
unsafe axiom set_basic_attribute (attr_name : Name) (c_name : Name) (persistent := false)
    (prio : Option Nat := none) : tactic Unit
#align tactic.set_basic_attribute tactic.set_basic_attribute

/-- `unset_attribute attr_name c_name` -/
unsafe axiom unset_attribute : Name → Name → tactic Unit
#align tactic.unset_attribute tactic.unset_attribute

/-- `has_attribute attr_name c_name` succeeds if the declaration `decl_name`
   has the attribute `attr_name`. The result is the priority and whether or not
   the attribute is persistent. -/
unsafe axiom has_attribute : Name → Name → tactic (Bool × Nat)
#align tactic.has_attribute tactic.has_attribute

/-- `copy_attribute attr_name c_name p d_name` copy attribute `attr_name` from
   `src` to `tgt` if it is defined for `src`; make it persistent if `p` is `tt`;
   if `p` is `none`, the copied attribute is made persistent iff it is persistent on `src`  -/
unsafe def copy_attribute (attr_name : Name) (src : Name) (tgt : Name) (p : Option Bool := none) :
    tactic Unit :=
  try do
    let (p', prio) ← has_attribute attr_name src
    let p := p.getD p'
    set_basic_attribute attr_name tgt p (some prio)
#align tactic.copy_attribute tactic.copy_attribute

/-- Name of the declaration currently being elaborated. -/
unsafe axiom decl_name : tactic Name
#align tactic.decl_name tactic.decl_name

/-- `save_type_info e ref` save (typeof e) at position associated with ref -/
unsafe axiom save_type_info {elab : Bool} : expr → expr elab → tactic Unit
#align tactic.save_type_info tactic.save_type_info

unsafe axiom save_info_thunk : Pos → (Unit → format) → tactic Unit
#align tactic.save_info_thunk tactic.save_info_thunk

/-- Return list of currently open namespaces -/
unsafe axiom open_namespaces : tactic (List Name)
#align tactic.open_namespaces tactic.open_namespaces

/-- Return tt iff `t` "occurs" in `e`. The occurrence checking is performed using
    keyed matching with the given transparency setting.

    We say `t` occurs in `e` by keyed matching iff there is a subterm `s`
    s.t. `t` and `s` have the same head, and `is_def_eq t s md`

    The main idea is to minimize the number of `is_def_eq` checks
    performed. -/
unsafe axiom kdepends_on (e t : expr) (md := reducible) : tactic Bool
#align tactic.kdepends_on tactic.kdepends_on

/-- Abstracts all occurrences of the term `t` in `e` using keyed matching.
    If `unify` is `ff`, then matching is used instead of unification.
    That is, metavariables occurring in `e` are not assigned. -/
unsafe axiom kabstract (e t : expr) (md := reducible) (unify := true) : tactic expr
#align tactic.kabstract tactic.kabstract

/-- Blocks the execution of the current thread for at least `msecs` milliseconds.
    This tactic is used mainly for debugging purposes. -/
unsafe axiom sleep (msecs : Nat) : tactic Unit
#align tactic.sleep tactic.sleep

/-- Type check `e` with respect to the current goal.
    Fails if `e` is not type correct. -/
unsafe axiom type_check (e : expr) (md := semireducible) : tactic Unit
#align tactic.type_check tactic.type_check

open List Nat

/-- A `tag` is a list of `names`. These are attached to goals to help tactics track them.-/
def Tag : Type :=
  List Name
#align tactic.tag Tactic.Tag

/-- Enable/disable goal tagging.  -/
unsafe axiom enable_tags (b : Bool) : tactic Unit
#align tactic.enable_tags tactic.enable_tags

/-- Return tt iff goal tagging is enabled. -/
unsafe axiom tags_enabled : tactic Bool
#align tactic.tags_enabled tactic.tags_enabled

/-- Tag goal `g` with tag `t`. It does nothing if goal tagging is disabled.
    Remark: `set_goal g []` removes the tag -/
unsafe axiom set_tag (g : expr) (t : Tag) : tactic Unit
#align tactic.set_tag tactic.set_tag

/-- Return tag associated with `g`. Return `[]` if there is no tag. -/
unsafe axiom get_tag (g : expr) : tactic Tag
#align tactic.get_tag tactic.get_tag

/-! By default, Lean only considers local instances in the header of declarations.
    This has two main benefits.
    1- Results produced by the type class resolution procedure can be easily cached.
    2- The set of local instances does not have to be recomputed.

    This approach has the following disadvantages:
    1- Frozen local instances cannot be reverted.
    2- Local instances defined inside of a declaration are not considered during type
       class resolution.
-/


/-- Avoid this function!  Use `unfreezingI`/`resetI`/etc. instead!

Unfreezes the current set of local instances.
After this tactic, the instance cache is disabled.
-/
unsafe axiom unfreeze_local_instances : tactic Unit
#align tactic.unfreeze_local_instances tactic.unfreeze_local_instances

/-- Freeze the current set of local instances.
-/
unsafe axiom freeze_local_instances : tactic Unit
#align tactic.freeze_local_instances tactic.freeze_local_instances

/-- Return the list of frozen local instances. Return `none` if local instances were not frozen. -/
unsafe axiom frozen_local_instances : tactic (Option (List expr))
#align tactic.frozen_local_instances tactic.frozen_local_instances

/-- Run the provided tactic, associating it to the given AST node. -/
unsafe axiom with_ast {α : Type u} (ast : ℕ) (t : tactic α) : tactic α
#align tactic.with_ast tactic.with_ast

unsafe def induction' (h : expr) (ns : List Name := []) (rec : Option Name := none)
    (md := semireducible) : tactic Unit :=
  induction h ns rec md >> return ()
#align tactic.induction' tactic.induction'

/-- Remark: set_goals will erase any solved goal -/
unsafe def cleanup : tactic Unit :=
  get_goals >>= set_goals
#align tactic.cleanup tactic.cleanup

/-- Auxiliary definition used to implement begin ... end blocks -/
unsafe def step {α : Type u} (t : tactic α) : tactic Unit :=
  t >>[tactic] cleanup
#align tactic.step tactic.step

unsafe def istep {α : Type u} (line0 col0 line col ast : ℕ) (t : tactic α) : tactic Unit := fun s =>
  (@scopeTrace _ line col fun _ => with_ast ast (step t) s).clamp_pos line0 line col
#align tactic.istep tactic.istep

unsafe def is_prop (e : expr) : tactic Bool := do
  let t ← infer_type e
  return (t = q(Prop))
#align tactic.is_prop tactic.is_prop

/-- Return true iff n is the name of declaration that is a proposition. -/
unsafe def is_prop_decl (n : Name) : tactic Bool := do
  let env ← get_env
  let d ← env.get n
  let t ← return <| d.type
  is_prop t
#align tactic.is_prop_decl tactic.is_prop_decl

unsafe def is_proof (e : expr) : tactic Bool :=
  infer_type e >>= is_prop
#align tactic.is_proof tactic.is_proof

unsafe def whnf_no_delta (e : expr) : tactic expr :=
  whnf e Transparency.none
#align tactic.whnf_no_delta tactic.whnf_no_delta

/-- Return `e` in weak head normal form with respect to the given transparency setting,
    or `e` head is a generalized constructor or inductive datatype. -/
unsafe def whnf_ginductive (e : expr) (md := semireducible) : tactic expr :=
  whnf e md false
#align tactic.whnf_ginductive tactic.whnf_ginductive

unsafe def whnf_target : tactic Unit :=
  target >>= whnf >>= change
#align tactic.whnf_target tactic.whnf_target

/-- Change the target of the main goal.
   The input expression must be definitionally equal to the current target.
   The tactic does not check whether `e`
   is definitionally equal to the current target. The error will only be detected by the kernel type checker. -/
unsafe def unsafe_change (e : expr) : tactic Unit :=
  change e false
#align tactic.unsafe_change tactic.unsafe_change

/-- Pi or elet introduction.
Given the tactic state `⊢ Π x : α, Y`, ``intro `hello`` will produce the state `hello : α ⊢ Y[x/hello]`.
Returns the new local constant. Similarly for `elet` expressions.
If the target is not a Pi or elet it will try to put it in WHNF.
 -/
unsafe def intro (n : Name) : tactic expr := do
  let t ← target
  if expr.is_pi t ∨ expr.is_let t then intro_core n else whnf_target >> intro_core n
#align tactic.intro tactic.intro

/-- A variant of `intro` which makes sure that the introduced hypothesis's name is
unique in the context. If there is no hypothesis named `n` in the context yet,
`intro_fresh n` is the same as `intro n`. If there is already a hypothesis named
`n`, the new hypothesis is named `n_1` (or `n_2` if `n_1` already exists, etc.).
If `offset` is given, the new names are `n_offset`, `n_offset+1` etc.

If `n` is `_`, `intro_fresh n` is the same as `intro1`. The `offset` is ignored
in this case.
-/
unsafe def intro_fresh (n : Name) (offset : Option Nat := none) : tactic expr :=
  if n = `_ then intro `_
  else do
    let n ← get_unused_name n offset
    intro n
#align tactic.intro_fresh tactic.intro_fresh

/-- Like `intro` except the name is derived from the bound name in the Π. -/
unsafe def intro1 : tactic expr :=
  intro `_
#align tactic.intro1 tactic.intro1

/--
Repeatedly apply `intro1` and return the list of new local constants in order of introduction. -/
unsafe def intros : tactic (List expr) := do
  let t ← target
  match t with
    | expr.pi _ _ _ _ => do
      let H ← intro1
      let Hs ← intros
      return (H :: Hs)
    | expr.elet _ _ _ _ => do
      let H ← intro1
      let Hs ← intros
      return (H :: Hs)
    | _ => return []
#align tactic.intros tactic.intros

/--
Same as `intros`, except with the given names for the new hypotheses. Use the name ```_``` to instead use the binder's name.-/
unsafe def intro_lst (ns : List Name) : tactic (List expr) :=
  ns.mapM intro
#align tactic.intro_lst tactic.intro_lst

/-- A variant of `intro_lst` which makes sure that the introduced hypotheses' names
are unique in the context. See `intro_fresh`.
-/
unsafe def intro_lst_fresh (ns : List Name) : tactic (List expr) :=
  ns.mapM intro_fresh
#align tactic.intro_lst_fresh tactic.intro_lst_fresh

/-- Introduces new hypotheses with forward dependencies.  -/
unsafe def intros_dep : tactic (List expr) := do
  let t ← target
  let proc (b : expr) :=
    if b.has_var_idx 0 then do
      let h ← intro1
      let hs ← intros_dep
      return (h :: hs)
    else-- body doesn't depend on new hypothesis
        return
        []
  match t with
    | expr.pi _ _ _ b => proc b
    | expr.elet _ _ _ b => proc b
    | _ => return []
#align tactic.intros_dep tactic.intros_dep

unsafe def introv : List Name → tactic (List expr)
  | [] => intros_dep
  | n :: ns => do
    let hs ← intros_dep
    let h ← intro n
    let hs' ← introv ns
    return (hs ++ h :: hs')
#align tactic.introv tactic.introv

/-- `intron' n` introduces `n` hypotheses and returns the resulting local
constants. Fails if there are not at least `n` arguments to introduce. If you do
not need the return value, use `intron`.
-/
unsafe def intron' (n : ℕ) : tactic (List expr) :=
  iterate_exactly n intro1
#align tactic.intron' tactic.intron'

/-- Like `intron'` but the introduced hypotheses' names are derived from `base`,
i.e. `base`, `base_1` etc. The new names are unique in the context. If `offset`
is given, the new names will be `base_offset`, `base_offset+1` etc.
-/
unsafe def intron_base (n : ℕ) (base : Name) (offset : Option Nat := none) : tactic (List expr) :=
  iterate_exactly n (intro_fresh base offset)
#align tactic.intron_base tactic.intron_base

/-- `intron_with i ns base offset` introduces `i` hypotheses using the names from
`ns`. If `ns` contains less than `i` names, the remaining hypotheses' names are
derived from `base` and `offset` (as with `intron_base`). If `base` is `_`, the
names are derived from the Π binder names.

Returns the introduced local constants and the remaining names from `ns` (if
`ns` contains more than `i` names).
-/
unsafe def intron_with :
    ℕ → List Name → optParam Name `_ → optParam (Option ℕ) none → tactic (List expr × List Name)
  | 0, ns, _, _ => pure ([], ns)
  | i + 1, [], base, offset => do
    let hs ← intron_base (i + 1) base offset
    pure (hs, [])
  | i + 1, n :: ns, base, offset => do
    let h ← intro n
    let ⟨hs, rest⟩ ← intron_with i ns base offset
    pure (h :: hs, rest)
#align tactic.intron_with tactic.intron_with

/-- Returns n fully qualified if it refers to a constant, or else fails. -/
unsafe def resolve_constant (n : Name) : tactic Name := do
  let e ← resolve_name n
  match e with
    | expr.const n _ => pure n
    | _ => do
      let e ← to_expr e tt ff
      let expr.const n _ ← pure <| e
      pure n
#align tactic.resolve_constant tactic.resolve_constant

unsafe def to_expr_strict (q : pexpr) : tactic expr :=
  to_expr q
#align tactic.to_expr_strict tactic.to_expr_strict

/--
Example: with `x : ℕ, h : P(x) ⊢ T(x)`, `revert x` returns `2` and produces the state ` ⊢ Π x, P(x) → T(x)`.
 -/
unsafe def revert (l : expr) : tactic Nat :=
  revert_lst [l]
#align tactic.revert tactic.revert

/-- Revert "all" hypotheses. Actually, the tactic only reverts
   hypotheses occurring after the last frozen local instance.
   Recall that frozen local instances cannot be reverted,
   use `unfreezing revert_all` instead. -/
unsafe def revert_all : tactic Nat := do
  let lctx ← local_context
  let lis ← frozen_local_instances
  match lis with
    | none => revert_lst lctx
    | some [] => revert_lst lctx
    |-- `hi` is the last local instance. We shoul truncate `lctx` at `hi`.
        some
        (hi :: his) =>
      revert_lst <| lctx (fun r h => if h = hi then [] else h :: r) []
#align tactic.revert_all tactic.revert_all

unsafe def clear_lst : List Name → tactic Unit
  | [] => skip
  | n :: ns => do
    let H ← get_local n
    clear H
    clear_lst ns
#align tactic.clear_lst tactic.clear_lst

unsafe def match_not (e : expr) : tactic expr :=
  match expr.is_not e with
  | some a => return a
  | none => fail "expression is not a negation"
#align tactic.match_not tactic.match_not

unsafe def match_and (e : expr) : tactic (expr × expr) :=
  match expr.is_and e with
  | some (α, β) => return (α, β)
  | none => fail "expression is not a conjunction"
#align tactic.match_and tactic.match_and

unsafe def match_or (e : expr) : tactic (expr × expr) :=
  match expr.is_or e with
  | some (α, β) => return (α, β)
  | none => fail "expression is not a disjunction"
#align tactic.match_or tactic.match_or

unsafe def match_iff (e : expr) : tactic (expr × expr) :=
  match expr.is_iff e with
  | some (lhs, rhs) => return (lhs, rhs)
  | none => fail "expression is not an iff"
#align tactic.match_iff tactic.match_iff

unsafe def match_eq (e : expr) : tactic (expr × expr) :=
  match expr.is_eq e with
  | some (lhs, rhs) => return (lhs, rhs)
  | none => fail "expression is not an equality"
#align tactic.match_eq tactic.match_eq

unsafe def match_ne (e : expr) : tactic (expr × expr) :=
  match expr.is_ne e with
  | some (lhs, rhs) => return (lhs, rhs)
  | none => fail "expression is not a disequality"
#align tactic.match_ne tactic.match_ne

unsafe def match_heq (e : expr) : tactic (expr × expr × expr × expr) := do
  match expr.is_heq e with
    | some (α, lhs, β, rhs) => return (α, lhs, β, rhs)
    | none => fail "expression is not a heterogeneous equality"
#align tactic.match_heq tactic.match_heq

unsafe def match_refl_app (e : expr) : tactic (Name × expr × expr) := do
  let env ← get_env
  match environment.is_refl_app env e with
    | some (R, lhs, rhs) => return (R, lhs, rhs)
    | none => fail "expression is not an application of a reflexive relation"
#align tactic.match_refl_app tactic.match_refl_app

unsafe def match_app_of (e : expr) (n : Name) : tactic (List expr) :=
  guard (expr.is_app_of e n) >> return e.get_app_args
#align tactic.match_app_of tactic.match_app_of

unsafe def get_local_type (n : Name) : tactic expr :=
  get_local n >>= infer_type
#align tactic.get_local_type tactic.get_local_type

unsafe def trace_result : tactic Unit :=
  format_result >>= trace
#align tactic.trace_result tactic.trace_result

unsafe def rexact (e : expr) : tactic Unit :=
  exact e reducible
#align tactic.rexact tactic.rexact

unsafe def any_hyp_aux {α : Type} (f : expr → tactic α) : List expr → tactic α
  | [] => failed
  | h :: hs => f h <|> any_hyp_aux hs
#align tactic.any_hyp_aux tactic.any_hyp_aux

unsafe def any_hyp {α : Type} (f : expr → tactic α) : tactic α :=
  local_context >>= any_hyp_aux f
#align tactic.any_hyp tactic.any_hyp

/-- `find_same_type t es` tries to find in es an expression with type definitionally equal to t -/
unsafe def find_same_type : expr → List expr → tactic expr
  | e, [] => failed
  | e, H :: Hs => do
    let t ← infer_type H
    unify e t >> return H <|> find_same_type e Hs
#align tactic.find_same_type tactic.find_same_type

unsafe def find_assumption (e : expr) : tactic expr := do
  let ctx ← local_context
  find_same_type e ctx
#align tactic.find_assumption tactic.find_assumption

unsafe def assumption : tactic Unit :=
  (do
      let ctx ← local_context
      let t ← target
      let H ← find_same_type t ctx
      exact H) <|>
    fail "assumption tactic failed"
#align tactic.assumption tactic.assumption

unsafe def save_info (p : Pos) : tactic Unit := do
  let s ← read
  tactic.save_info_thunk p fun _ => tactic_state.to_format s
#align tactic.save_info tactic.save_info

/-- Swap first two goals, do nothing if tactic state does not have at least two goals. -/
unsafe def swap : tactic Unit := do
  let gs ← get_goals
  match gs with
    | g₁ :: g₂ :: rs => set_goals (g₂ :: g₁ :: rs)
    | e => skip
#align tactic.swap tactic.swap

/-- `assert h t`, adds a new goal for t, and the hypothesis `h : t` in the current goal. -/
unsafe def assert (h : Name) (t : expr) : tactic expr := do
  assert_core h t
  swap
  let e ← intro h
  swap
  return e
#align tactic.assert tactic.assert

/-- `assertv h t v`, adds the hypothesis `h : t` in the current goal if v has type t. -/
unsafe def assertv (h : Name) (t : expr) (v : expr) : tactic expr :=
  assertv_core h t v >> intro h
#align tactic.assertv tactic.assertv

/-- `define h t`, adds a new goal for t, and the hypothesis `h : t := ?M` in the current goal. -/
unsafe def define (h : Name) (t : expr) : tactic expr := do
  define_core h t
  swap
  let e ← intro h
  swap
  return e
#align tactic.define tactic.define

/-- `definev h t v`, adds the hypothesis (h : t := v) in the current goal if v has type t. -/
unsafe def definev (h : Name) (t : expr) (v : expr) : tactic expr :=
  definev_core h t v >> intro h
#align tactic.definev tactic.definev

/-- Add `h : t := pr` to the current goal -/
unsafe def pose (h : Name) (t : Option expr := none) (pr : expr) : tactic expr :=
  let dv t := definev h t pr
  Option.casesOn t (infer_type pr >>= dv) dv
#align tactic.pose tactic.pose

/-- Add `h : t` to the current goal, given a proof `pr : t` -/
unsafe def note (h : Name) (t : Option expr := none) (pr : expr) : tactic expr :=
  let dv t := assertv h t pr
  Option.casesOn t (infer_type pr >>= dv) dv
#align tactic.note tactic.note

/-- Return the number of goals that need to be solved -/
unsafe def num_goals : tactic Nat := do
  let gs ← get_goals
  return (length gs)
#align tactic.num_goals tactic.num_goals

/--
Rotate the goals to the right by `n`. That is, take the goal at the back and push it to the front `n` times.
[NOTE] We have to provide the instance argument `[has_mod nat]` because
   mod for nat was not defined yet -/
unsafe def rotate_right (n : Nat) [Mod Nat] : tactic Unit := do
  let ng ← num_goals
  if ng = 0 then skip else rotate_left (ng - n % ng)
#align tactic.rotate_right tactic.rotate_right

/-- Rotate the goals to the left by `n`. That is, put the main goal to the back `n` times. -/
unsafe def rotate : Nat → tactic Unit :=
  rotate_left
#align tactic.rotate tactic.rotate

private unsafe def repeat_aux (t : tactic Unit) : List expr → List expr → tactic Unit
  | [], r => set_goals r.reverse
  | g :: gs, r => do
    let ok ← try_core (set_goals [g] >> t)
    match ok with
      | none => repeat_aux gs (g :: r)
      | _ => do
        let gs' ← get_goals
        repeat_aux (gs' ++ gs) r
#align tactic.repeat_aux tactic.repeat_aux

/-- This tactic is applied to each goal. If the application succeeds,
    the tactic is applied recursively to all the generated subgoals until it eventually fails.
    The recursion stops in a subgoal when the tactic has failed to make progress.
    The tactic `repeat` never fails. -/
unsafe def repeat (t : tactic Unit) : tactic Unit := do
  let gs ← get_goals
  repeat_aux t gs []
#align tactic.repeat tactic.repeat

/-- `first [t_1, ..., t_n]` applies the first tactic that doesn't fail.
   The tactic fails if all t_i's fail. -/
unsafe def first {α : Type u} : List (tactic α) → tactic α
  | [] => fail "first tactic failed, no more alternatives"
  | t :: ts => t <|> first ts
#align tactic.first tactic.first

/-- Applies the given tactic to the main goal and fails if it is not solved. -/
unsafe def solve1 {α} (tac : tactic α) : tactic α := do
  let gs ← get_goals
  match gs with
    | [] => fail "solve1 tactic failed, there isn't any goal left to focus"
    | g :: rs => do
      set_goals [g]
      let a ← tac
      let gs' ← get_goals
      match gs' with
        | [] => set_goals rs >> pure a
        | gs => fail "solve1 tactic failed, focused goal has not been solved"
#align tactic.solve1 tactic.solve1

/-- `solve [t_1, ... t_n]` applies the first tactic that solves the main goal. -/
unsafe def solve {α} (ts : List (tactic α)) : tactic α :=
  first <| map solve1 ts
#align tactic.solve tactic.solve

private unsafe def focus_aux {α} : List (tactic α) → List expr → List expr → tactic (List α)
  | [], [], rs => set_goals rs *> pure []
  | t :: ts, [], rs => fail "focus tactic failed, insufficient number of goals"
  | tts, g :: gs, rs =>
    condM (is_assigned g) (focus_aux tts gs rs) do
      set_goals [g]
      let t :: ts ← pure tts |
        fail "focus tactic failed, insufficient number of tactics"
      let a ← t
      let rs' ← get_goals
      let as ← focus_aux ts gs (rs ++ rs')
      pure <| a :: as
#align tactic.focus_aux tactic.focus_aux

/-- `focus [t_1, ..., t_n]` applies t_i to the i-th goal. Fails if the number of
goals is not n. Returns the results of t_i (one per goal).
-/
unsafe def focus {α} (ts : List (tactic α)) : tactic (List α) := do
  let gs ← get_goals
  focus_aux ts gs []
#align tactic.focus tactic.focus

private unsafe def focus'_aux : List (tactic Unit) → List expr → List expr → tactic Unit
  | [], [], rs => set_goals rs
  | t :: ts, [], rs => fail "focus' tactic failed, insufficient number of goals"
  | tts, g :: gs, rs =>
    condM (is_assigned g) (focus'_aux tts gs rs) do
      set_goals [g]
      let t :: ts ← pure tts |
        fail "focus' tactic failed, insufficient number of tactics"
      t
      let rs' ← get_goals
      focus'_aux ts gs (rs ++ rs')
#align tactic.focus'_aux tactic.focus'_aux

/-- `focus' [t_1, ..., t_n]` applies t_i to the i-th goal. Fails if the number of goals is not n. -/
unsafe def focus' (ts : List (tactic Unit)) : tactic Unit := do
  let gs ← get_goals
  focus'_aux ts gs []
#align tactic.focus' tactic.focus'

unsafe def focus1 {α} (tac : tactic α) : tactic α := do
  let g :: gs ← get_goals
  match gs with
    | [] => tac
    | _ => do
      set_goals [g]
      let a ← tac
      let gs' ← get_goals
      set_goals (gs' ++ gs)
      return a
#align tactic.focus1 tactic.focus1

private unsafe def all_goals_core {α} (tac : tactic α) : List expr → List expr → tactic (List α)
  | [], ac => set_goals ac *> pure []
  | g :: gs, ac =>
    condM (is_assigned g) (all_goals_core gs ac) do
      set_goals [g]
      let a ← tac
      let new_gs ← get_goals
      let as ← all_goals_core gs (ac ++ new_gs)
      pure <| a :: as
#align tactic.all_goals_core tactic.all_goals_core

/-- Apply the given tactic to all goals. Return one result per goal.
-/
unsafe def all_goals {α} (tac : tactic α) : tactic (List α) := do
  let gs ← get_goals
  all_goals_core tac gs []
#align tactic.all_goals tactic.all_goals

private unsafe def all_goals'_core (tac : tactic Unit) : List expr → List expr → tactic Unit
  | [], ac => set_goals ac
  | g :: gs, ac =>
    condM (is_assigned g) (all_goals'_core gs ac) do
      set_goals [g]
      tac
      let new_gs ← get_goals
      all_goals'_core gs (ac ++ new_gs)
#align tactic.all_goals'_core tactic.all_goals'_core

/-- Apply the given tactic to all goals. -/
unsafe def all_goals' (tac : tactic Unit) : tactic Unit := do
  let gs ← get_goals
  all_goals'_core tac gs []
#align tactic.all_goals' tactic.all_goals'

private unsafe def any_goals_core {α} (tac : tactic α) :
    List expr → List expr → Bool → tactic (List (Option α))
  | [], ac, progress => guard progress *> set_goals ac *> pure []
  | g :: gs, ac, progress =>
    condM (is_assigned g) (any_goals_core gs ac progress) do
      set_goals [g]
      let res ← try_core tac
      let new_gs ← get_goals
      let ress ← any_goals_core gs (ac ++ new_gs) (res.isSome || progress)
      pure <| res :: ress
#align tactic.any_goals_core tactic.any_goals_core

/-- Apply `tac` to any goal where it succeeds. The tactic succeeds if `tac`
succeeds for at least one goal. The returned list contains the result of `tac`
for each goal: `some a` if tac succeeded, or `none` if it did not.
-/
unsafe def any_goals {α} (tac : tactic α) : tactic (List (Option α)) := do
  let gs ← get_goals
  any_goals_core tac gs [] ff
#align tactic.any_goals tactic.any_goals

private unsafe def any_goals'_core (tac : tactic Unit) : List expr → List expr → Bool → tactic Unit
  | [], ac, progress => guard progress >> set_goals ac
  | g :: gs, ac, progress =>
    condM (is_assigned g) (any_goals'_core gs ac progress) do
      set_goals [g]
      let succeeded ← try_core tac
      let new_gs ← get_goals
      any_goals'_core gs (ac ++ new_gs) (succeeded || progress)
#align tactic.any_goals'_core tactic.any_goals'_core

/-- Apply the given tactic to any goal where it succeeds. The tactic succeeds only if
   tac succeeds for at least one goal. -/
unsafe def any_goals' (tac : tactic Unit) : tactic Unit := do
  let gs ← get_goals
  any_goals'_core tac gs [] ff
#align tactic.any_goals' tactic.any_goals'

/-- LCF-style AND_THEN tactic. It applies `tac1` to the main goal, then applies
`tac2` to each goal produced by `tac1`.
-/
unsafe def seq {α β} (tac1 : tactic α) (tac2 : α → tactic β) : tactic (List β) := do
  let g :: gs ← get_goals
  set_goals [g]
  let a ← tac1
  let bs ← all_goals <| tac2 a
  let gs' ← get_goals
  set_goals (gs' ++ gs)
  pure bs
#align tactic.seq tactic.seq

/--
LCF-style AND_THEN tactic. It applies tac1, and if succeed applies tac2 to each subgoal produced by tac1 -/
unsafe def seq' (tac1 : tactic Unit) (tac2 : tactic Unit) : tactic Unit := do
  let g :: gs ← get_goals
  set_goals [g]
  tac1
  all_goals' tac2
  let gs' ← get_goals
  set_goals (gs' ++ gs)
#align tactic.seq' tactic.seq'

/-- Applies `tac1` to the main goal, then applies each of the tactics in `tacs2` to
one of the produced subgoals (like `focus'`).
-/
unsafe def seq_focus {α β} (tac1 : tactic α) (tacs2 : α → List (tactic β)) : tactic (List β) := do
  let g :: gs ← get_goals
  set_goals [g]
  let a ← tac1
  let bs ← focus <| tacs2 a
  let gs' ← get_goals
  set_goals (gs' ++ gs)
  pure bs
#align tactic.seq_focus tactic.seq_focus

/-- Applies `tac1` to the main goal, then applies each of the tactics in `tacs2` to
one of the produced subgoals (like `focus`).
-/
unsafe def seq_focus' (tac1 : tactic Unit) (tacs2 : List (tactic Unit)) : tactic Unit := do
  let g :: gs ← get_goals
  set_goals [g]
  tac1
  focus tacs2
  let gs' ← get_goals
  set_goals (gs' ++ gs)
#align tactic.seq_focus' tactic.seq_focus'

unsafe instance andthen_seq : AndThen' (tactic Unit) (tactic Unit) (tactic Unit) :=
  ⟨seq'⟩
#align tactic.andthen_seq tactic.andthen_seq

unsafe instance andthen_seq_focus : AndThen' (tactic Unit) (List (tactic Unit)) (tactic Unit) :=
  ⟨seq_focus'⟩
#align tactic.andthen_seq_focus tactic.andthen_seq_focus

unsafe axiom is_trace_enabled_for : Name → Bool
#align tactic.is_trace_enabled_for tactic.is_trace_enabled_for

/-- Execute tac only if option trace.n is set to true. -/
unsafe def when_tracing (n : Name) (tac : tactic Unit) : tactic Unit :=
  when (is_trace_enabled_for n = true) tac
#align tactic.when_tracing tactic.when_tracing

/-- Fail if there are no remaining goals. -/
unsafe def fail_if_no_goals : tactic Unit := do
  let n ← num_goals
  when (n = 0) (fail "tactic failed, there are no goals to be solved")
#align tactic.fail_if_no_goals tactic.fail_if_no_goals

/-- Fail if there are unsolved goals. -/
unsafe def done : tactic Unit := do
  let n ← num_goals
  when (n ≠ 0) (fail "done tactic failed, there are unsolved goals")
#align tactic.done tactic.done

unsafe def apply_opt_param : tactic Unit := do
  let q(optParam $(t) $(v)) ← target
  exact v
#align tactic.apply_opt_param tactic.apply_opt_param

unsafe def apply_auto_param : tactic Unit := do
  let q(autoParam $(type) $(tac_name_expr)) ← target
  change type
  let tac_name ← eval_expr Name tac_name_expr
  let tac ← eval_expr (tactic Unit) (expr.const tac_name [])
  tac
#align tactic.apply_auto_param tactic.apply_auto_param

unsafe def has_opt_auto_param (ms : List expr) : tactic Bool :=
  ms.foldlM
    (fun r m => do
      let type ← infer_type m
      return <| r || type `opt_param 2 || type `auto_param 2)
    false
#align tactic.has_opt_auto_param tactic.has_opt_auto_param

unsafe def try_apply_opt_auto_param (cfg : ApplyCfg) (ms : List expr) : tactic Unit :=
  when (cfg.autoParamₓ || cfg.optParam) <|
    whenM (has_opt_auto_param ms) do
      let gs ← get_goals
      ms fun m =>
          whenM (not <$> is_assigned m) <|
            (set_goals [m] >> when cfg (try apply_opt_param)) >> when cfg (try apply_auto_param)
      set_goals gs
#align tactic.try_apply_opt_auto_param tactic.try_apply_opt_auto_param

unsafe def has_opt_auto_param_for_apply (ms : List (Name × expr)) : tactic Bool :=
  ms.foldlM
    (fun r m => do
      let type ← infer_type m.2
      return <| r || type `opt_param 2 || type `auto_param 2)
    false
#align tactic.has_opt_auto_param_for_apply tactic.has_opt_auto_param_for_apply

unsafe def try_apply_opt_auto_param_for_apply (cfg : ApplyCfg) (ms : List (Name × expr)) :
    tactic Unit :=
  whenM (has_opt_auto_param_for_apply ms) do
    let gs ← get_goals
    ms fun m =>
        whenM (not <$> is_assigned m.2) <|
          (set_goals [m.2] >> when cfg (try apply_opt_param)) >> when cfg (try apply_auto_param)
    set_goals gs
#align tactic.try_apply_opt_auto_param_for_apply tactic.try_apply_opt_auto_param_for_apply

unsafe def apply (e : expr) (cfg : ApplyCfg := { }) : tactic (List (Name × expr)) := do
  let r ← apply_core e cfg
  try_apply_opt_auto_param_for_apply cfg r
  return r
#align tactic.apply tactic.apply

/-- Same as `apply` but __all__ arguments that weren't inferred are added to goal list. -/
unsafe def fapply (e : expr) : tactic (List (Name × expr)) :=
  apply e { NewGoals := NewGoals.all }
#align tactic.fapply tactic.fapply

/-- Same as `apply` but only goals that don't depend on other goals are added to goal list. -/
unsafe def eapply (e : expr) : tactic (List (Name × expr)) :=
  apply e { NewGoals := NewGoals.non_dep_only }
#align tactic.eapply tactic.eapply

/-- Try to solve the main goal using type class resolution. -/
unsafe def apply_instance : tactic Unit := do
  let tgt ← target >>= instantiate_mvars
  let b ← is_class tgt
  if b then mk_instance tgt >>= exact
    else fail "apply_instance tactic fail, target is not a type class"
#align tactic.apply_instance tactic.apply_instance

/-- Create a list of universe meta-variables of the given size. -/
unsafe def mk_num_meta_univs : Nat → tactic (List level)
  | 0 => return []
  | succ n => do
    let l ← mk_meta_univ
    let ls ← mk_num_meta_univs n
    return (l :: ls)
#align tactic.mk_num_meta_univs tactic.mk_num_meta_univs

/-- Return `expr.const c [l_1, ..., l_n]` where l_i's are fresh universe meta-variables. -/
unsafe def mk_const (c : Name) : tactic expr := do
  let env ← get_env
  let decl ← env.get c
  let num := decl.univ_params.length
  let ls ← mk_num_meta_univs Num
  return (expr.const c ls)
#align tactic.mk_const tactic.mk_const

/-- Apply the constant `c` -/
unsafe def applyc (c : Name) (cfg : ApplyCfg := { }) : tactic Unit := do
  let c ← mk_const c
  apply c cfg
  skip
#align tactic.applyc tactic.applyc

unsafe def eapplyc (c : Name) : tactic Unit := do
  let c ← mk_const c
  eapply c
  skip
#align tactic.eapplyc tactic.eapplyc

unsafe def save_const_type_info (n : Name) {elab : Bool} (ref : expr elab) : tactic Unit :=
  try do
    let c ← mk_const n
    save_type_info c ref
#align tactic.save_const_type_info tactic.save_const_type_info

/-- Create a fresh universe `?u`, a metavariable `?T : Type.{?u}`,
   and return metavariable `?M : ?T`.
   This action can be used to create a meta-variable when
   we don't know its type at creation time -/
unsafe def mk_mvar : tactic expr := do
  let u ← mk_meta_univ
  let t ← mk_meta_var (expr.sort u)
  mk_meta_var t
#align tactic.mk_mvar tactic.mk_mvar

/-- Makes a sorry macro with a meta-variable as its type. -/
unsafe def mk_sorry : tactic expr := do
  let u ← mk_meta_univ
  let t ← mk_meta_var (expr.sort u)
  return <| expr.mk_sorry t
#align tactic.mk_sorry tactic.mk_sorry

/-- Closes the main goal using sorry. -/
unsafe def admit : tactic Unit :=
  target >>= exact ∘ expr.mk_sorry
#align tactic.admit tactic.admit

unsafe def mk_local' (pp_name : Name) (bi : BinderInfo) (type : expr) : tactic expr := do
  let uniq_name ← mk_fresh_name
  return <| expr.local_const uniq_name pp_name bi type
#align tactic.mk_local' tactic.mk_local'

unsafe def mk_local_def (pp_name : Name) (type : expr) : tactic expr :=
  mk_local' pp_name BinderInfo.default type
#align tactic.mk_local_def tactic.mk_local_def

unsafe def mk_local_pis : expr → tactic (List expr × expr)
  | expr.pi n bi d b => do
    let p ← mk_local' n bi d
    let (ps, r) ← mk_local_pis (expr.instantiate_var b p)
    return (p :: ps, r)
  | e => return ([], e)
#align tactic.mk_local_pis tactic.mk_local_pis

private unsafe def get_pi_arity_aux : expr → tactic Nat
  | expr.pi n bi d b => do
    let m ← mk_fresh_name
    let l := expr.local_const m n bi d
    let new_b ← whnf (expr.instantiate_var b l)
    let r ← get_pi_arity_aux new_b
    return (r + 1)
  | e => return 0
#align tactic.get_pi_arity_aux tactic.get_pi_arity_aux

/-- Compute the arity of the given (Pi-)type -/
unsafe def get_pi_arity (type : expr) : tactic Nat :=
  whnf type >>= get_pi_arity_aux
#align tactic.get_pi_arity tactic.get_pi_arity

/-- Compute the arity of the given function -/
unsafe def get_arity (fn : expr) : tactic Nat :=
  infer_type fn >>= get_pi_arity
#align tactic.get_arity tactic.get_arity

unsafe def triv : tactic Unit :=
  mk_const `trivial >>= exact
#align tactic.triv tactic.triv

unsafe def by_contradiction (H : Name) : tactic expr := do
  let tgt ← target
  let tgt_wh ← whnf tgt reducible
  -- to ensure that `not` in `ne` is found
          match_not
          tgt_wh $>
        () <|>
      (mk_mapp `decidable.by_contradiction [some tgt, none] >>= eapply) >> skip <|>
        (mk_mapp `classical.by_contradiction [some tgt] >>= eapply) >> skip <|>
          fail "tactic by_contradiction failed, target is not a proposition"
  intro H
#align tactic.by_contradiction tactic.by_contradiction

private unsafe def generalizes_aux (md : Transparency) : List expr → tactic Unit
  | [] => skip
  | e :: es => generalize e `x md >> generalizes_aux es
#align tactic.generalizes_aux tactic.generalizes_aux

unsafe def generalizes (es : List expr) (md := semireducible) : tactic Unit :=
  generalizes_aux md es
#align tactic.generalizes tactic.generalizes

private unsafe def kdependencies_core (e : expr) (md : Transparency) :
    List expr → List expr → tactic (List expr)
  | [], r => return r
  | h :: hs, r => do
    let type ← infer_type h
    let d ← kdepends_on type e md
    if d then kdependencies_core hs (h :: r) else kdependencies_core hs r
#align tactic.kdependencies_core tactic.kdependencies_core

/-- Return all hypotheses that depends on `e`
    The dependency test is performed using `kdepends_on` with the given transparency setting. -/
unsafe def kdependencies (e : expr) (md := reducible) : tactic (List expr) := do
  let ctx ← local_context
  kdependencies_core e md ctx []
#align tactic.kdependencies tactic.kdependencies

/-- Revert all hypotheses that depend on `e` -/
unsafe def revert_kdependencies (e : expr) (md := reducible) : tactic Nat :=
  kdependencies e md >>= revert_lst
#align tactic.revert_kdependencies tactic.revert_kdependencies

unsafe def revert_kdeps (e : expr) (md := reducible) :=
  revert_kdependencies e md
#align tactic.revert_kdeps tactic.revert_kdeps

/-- Postprocess the output of `cases_core`:

- The third component of each tuple in the input list (the list of
  substitutions) is dropped since we don't use it anywhere.
- The second component (the list of new hypotheses) is filtered: any expression
  that is not a local constant is dropped. We only use the new hypotheses for
  the renaming functionality of `case`, so we want to keep only those
  "new hypotheses" that are, in fact, local constants. -/
private unsafe def cases_postprocess (hs : List (Name × List expr × List (Name × expr))) :
    List (Name × List expr) :=
  hs.map fun ⟨n, hs, _⟩ => (n, hs.filterₓ fun h => h.is_local_constant)
#align tactic.cases_postprocess tactic.cases_postprocess

/-- Similar to `cases_core`, but `e` doesn't need to be a hypothesis.
    Remark, it reverts dependencies using `revert_kdeps`.

    Two different transparency modes are used `md` and `dmd`.
    The mode `md` is used with `cases_core` and `dmd` with `generalize` and `revert_kdeps`.

    It returns the constructor names associated with each new goal and the newly
    introduced hypotheses. Note that while `cases_core` may return "new
    hypotheses" that are not local constants, this tactic only returns local
    constants.
-/
unsafe def cases (e : expr) (ids : List Name := []) (md := semireducible) (dmd := semireducible) :
    tactic (List (Name × List expr)) :=
  if e.is_local_constant then do
    let r ← cases_core e ids md
    return <| cases_postprocess r
  else do
    let n ← revert_kdependencies e dmd
    let x ← get_unused_name
    tactic.generalize e x dmd <|> do
        let t ← infer_type e
        tactic.assertv x t e
        get_local x >>= tactic.revert
        return ()
    let h ← tactic.intro1
    focus1 do
        let r ← cases_core h ids md
        let hs' ← all_goals (intron' n)
        return <| cases_postprocess <| r (fun ⟨n, hs, x⟩ hs' => (n, hs ++ hs', x)) hs'
#align tactic.cases tactic.cases

/-- The same as `exact` except you can add proof holes. -/
unsafe def refine (e : pexpr) : tactic Unit := do
  let tgt : expr ← target
  to_expr ``(($(e) : $(tgt))) tt >>= exact
#align tactic.refine tactic.refine

/-- `by_cases p h` splits the main goal into two cases, assuming `h : p` in the
first branch, and `h : ¬ p` in the second branch. The expression `p` needs to
be a proposition.

The produced proof term is `dite p ?m_1 ?m_2`.
-/
unsafe def by_cases (e : expr) (h : Name) : tactic Unit := do
  let dec_e ← mk_app `` Decidable [e] <|> fail "by_cases tactic failed, type is not a proposition"
  let inst ← mk_instance dec_e <|> pure q(Classical.propDecidable $(e))
  let tgt ← target
  let expr.sort tgt_u ← infer_type tgt >>= whnf
  let g1 ← mk_meta_var (e.imp tgt)
  let g2 ← mk_meta_var (q(¬$(e)).imp tgt)
  focus1 do
      exact <| expr.const `` dite [tgt_u] tgt e inst g1 g2
      set_goals [g1, g2]
      all_goals' <| intro h >> skip
#align tactic.by_cases tactic.by_cases

unsafe def funext_core : List Name → Bool → tactic Unit
  | [], tt => return ()
  | ids, only_ids =>
    try do
      let some (lhs, rhs) ← expr.is_eq <$> (target >>= whnf)
      applyc `funext
      let id ←
        if ids.Empty ∨ ids.headI = `_ then do
            let expr.lam n _ _ _ ← whnf lhs |
              pure `_
            return n
          else return ids.headI
      intro id
      funext_core ids only_ids
#align tactic.funext_core tactic.funext_core

unsafe def funext : tactic Unit :=
  funext_core [] false
#align tactic.funext tactic.funext

unsafe def funext_lst (ids : List Name) : tactic Unit :=
  funext_core ids true
#align tactic.funext_lst tactic.funext_lst

private unsafe def get_undeclared_const (env : environment) (base : Name) : ℕ → Name
  | i =>
    let n := .str base ("_aux_" ++ repr i)
    if ¬env.contains n then n else get_undeclared_const (i + 1)
#align tactic.get_undeclared_const tactic.get_undeclared_const

unsafe def new_aux_decl_name : tactic Name := do
  let env ← get_env
  let n ← decl_name
  return <| get_undeclared_const env n 1
#align tactic.new_aux_decl_name tactic.new_aux_decl_name

private unsafe def mk_aux_decl_name : Option Name → tactic Name
  | none => new_aux_decl_name
  | some suffix => do
    let p ← decl_name
    return <| p ++ suffix
#align tactic.mk_aux_decl_name tactic.mk_aux_decl_name

unsafe def abstract (tac : tactic Unit) (suffix : Option Name := none) (zeta_reduce := true) :
    tactic Unit := do
  fail_if_no_goals
  let gs ← get_goals
  let type ← if zeta_reduce then target >>= zeta else target
  let is_lemma ← is_prop type
  let m ← mk_meta_var type
  set_goals [m]
  tac
  let n ← num_goals
  when (n ≠ 0) (fail "abstract tactic failed, there are unsolved goals")
  set_goals gs
  let val ← instantiate_mvars m
  let val ← if zeta_reduce then zeta val else return val
  let c ← mk_aux_decl_name suffix
  let e ← add_aux_decl c type val is_lemma
  exact e
#align tactic.abstract tactic.abstract

/-- `solve_aux type tac` synthesize an element of 'type' using tactic 'tac' -/
unsafe def solve_aux {α : Type} (type : expr) (tac : tactic α) : tactic (α × expr) := do
  let m ← mk_meta_var type
  let gs ← get_goals
  set_goals [m]
  let a ← tac
  set_goals gs
  return (a, m)
#align tactic.solve_aux tactic.solve_aux

/-- Return tt iff 'd' is a declaration in one of the current open namespaces -/
unsafe def in_open_namespaces (d : Name) : tactic Bool := do
  let ns ← open_namespaces
  let env ← get_env
  return <| (ns fun n => n d) && env d
#align tactic.in_open_namespaces tactic.in_open_namespaces

/-- Execute tac for 'max' "heartbeats". The heartbeat is approx. the maximum number of
    memory allocations (in thousands) performed by 'tac'. This is a deterministic way of interrupting
    long running tactics. -/
unsafe def try_for {α} (max : Nat) (tac : tactic α) : tactic α := fun s =>
  match _root_.try_for max (tac s) with
  | some r => r
  | none => mk_exception "try_for tactic failed, timeout" none s
#align tactic.try_for tactic.try_for

/-- Execute `tac` for `max` milliseconds. Useful due to variance
    in the number of heartbeats taken by various tactics. -/
unsafe def try_for_time {α} (max : Nat) (tac : tactic α) : tactic α := fun s =>
  match _root_.try_for_time max (tac s) with
  | some r => r
  | none => mk_exception "try_for_time tactic failed, timeout" none s
#align tactic.try_for_time tactic.try_for_time

unsafe def updateex_env (f : environment → exceptional environment) : tactic Unit := do
  let env ← get_env
  let env ← returnex <| f env
  set_env env
#align tactic.updateex_env tactic.updateex_env

/-- Add a new inductive datatype to the environment
   name, universe parameters, number of parameters, type, constructors (name and type), is_meta -/
unsafe def add_inductive (n : Name) (ls : List Name) (p : Nat) (ty : expr) (is : List (Name × expr))
    (is_meta : Bool := false) : tactic Unit :=
  updateex_env fun e => e.add_inductive n ls p ty is is_meta
#align tactic.add_inductive tactic.add_inductive

unsafe def add_meta_definition (n : Name) (lvls : List Name) (type value : expr) : tactic Unit :=
  add_decl (declaration.defn n lvls type value ReducibilityHints.abbrev false)
#align tactic.add_meta_definition tactic.add_meta_definition

/-- add declaration `d` as a protected declaration -/
unsafe def add_protected_decl (d : declaration) : tactic Unit :=
  updateex_env fun e => e.add_protected d
#align tactic.add_protected_decl tactic.add_protected_decl

/-- check if `n` is the name of a protected declaration -/
unsafe def is_protected_decl (n : Name) : tactic Bool := do
  let env ← get_env
  return <| env n
#align tactic.is_protected_decl tactic.is_protected_decl

/-- `add_defn_equations` adds a definition specified by a list of equations.

  The arguments:
    * `lp`: list of universe parameters
    * `params`: list of parameters (binders before the colon);
    * `fn`: a local constant giving the name and type of the declaration
      (with `params` in the local context);
    * `eqns`: a list of equations, each of which is a list of patterns
      (constructors applied to new local constants) and the branch
      expression;
    * `is_meta`: is the definition meta?


  `add_defn_equations` can be used as:

      do my_add ← mk_local_def `my_add `(ℕ → ℕ),
          a ← mk_local_def `a ℕ,
          b ← mk_local_def `b ℕ,
          add_defn_equations [a] my_add
              [ ([``(nat.zero)], a),
                ([``(nat.succ %%b)], my_add b) ])
              ff -- non-meta

  to create the following definition:

      def my_add (a : ℕ) : ℕ → ℕ
      | nat.zero := a
      | (nat.succ b) := my_add b
-/
unsafe def add_defn_equations (lp : List Name) (params : List expr) (fn : expr)
    (eqns : List (List pexpr × expr)) (is_meta : Bool) : tactic Unit := do
  let opt ← get_options
  updateex_env fun e => e opt lp params fn eqns is_meta
#align tactic.add_defn_equations tactic.add_defn_equations

/-- Get the revertible part of the local context. These are the hypotheses that
appear after the last frozen local instance in the local context. We call them
revertible because `revert` can revert them, unlike those hypotheses which occur
before a frozen instance. -/
unsafe def revertible_local_context : tactic (List expr) := do
  let ctx ← local_context
  let frozen ← frozen_local_instances
  pure <|
      match frozen with
      | none => ctx
      | some [] => ctx
      | some (h :: _) => ctx (Eq h)
#align tactic.revertible_local_context tactic.revertible_local_context

/-- Rename local hypotheses according to the given `name_map`. The `name_map`
contains as keys those hypotheses that should be renamed; the associated values
are the new names.

This tactic can only rename hypotheses which occur after the last frozen local
instance. If you need to rename earlier hypotheses, try
`unfreezing (rename_many ...)`.

If `strict` is true, we fail if `name_map` refers to hypotheses that do not
appear in the local context or that appear before a frozen local instance.
Conversely, if `strict` is false, some entries of `name_map` may be silently
ignored.

If `use_unique_names` is true, the keys of `name_map` should be the unique names
of hypotheses to be renamed. Otherwise, the keys should be display names.

Note that we allow shadowing, so renamed hypotheses may have the same name
as other hypotheses in the context. If `use_unique_names` is false and there are
multiple hypotheses with the same display name in the context, they are all
renamed.
-/
unsafe def rename_many (renames : name_map Name) (strict := true) (use_unique_names := false) :
    tactic Unit := do
  let hyp_name : expr → Name :=
    if use_unique_names then expr.local_uniq_name else expr.local_pp_name
  let ctx ← revertible_local_context
  let-- The part of the context after (but including) the first hypthesis that
  -- must be renamed.
  ctx_suffix := ctx.dropWhileₓ fun h => (renames.find <| hyp_name h).isNone
  when strict do
      let ctx_names := rb_map.set_of_list (ctx_suffix hyp_name)
      let invalid_renames := (renames Prod.fst).filterₓ fun h => ¬ctx_names h
      when ¬invalid_renames <|
          fail <|
            format.join
              ["Cannot rename these hypotheses:\n",
                format.join <| (invalid_renames to_fmt).intersperse ", ", format.line,
                "This is because these hypotheses either do not occur in the\n",
                "context or they occur before a frozen local instance.\n",
                "In the latter case, try `unfreezingI { ... }`."]
  let-- The new names for all hypotheses in ctx_suffix.
  new_names := ctx_suffix.map fun h => (renames.find <| hyp_name h).getD h.local_pp_name
  revert_lst ctx_suffix
  intro_lst new_names
  pure ()
#align tactic.rename_many tactic.rename_many

/-- Rename a local hypothesis. This is a special case of `rename_many`;
see there for caveats.
-/
unsafe def rename (curr : Name) (new : Name) : tactic Unit :=
  rename_many (rb_map.of_list [⟨curr, new⟩])
#align tactic.rename tactic.rename

/-- Rename a local hypothesis. Unlike `rename` and `rename_many`, this tactic does
not preserve the order of hypotheses. Its implementation is simpler (and
therefore probably faster) than that of `rename`.
-/
unsafe def rename_unstable (curr : Name) (new : Name) : tactic Unit := do
  let h ← get_local curr
  let n ← revert h
  intro new
  intron (n - 1)
#align tactic.rename_unstable tactic.rename_unstable

/-- "Replace" hypothesis `h : type` with `h : new_type` where `eq_pr` is a proof
that (type = new_type). The tactic actually creates a new hypothesis
with the same user facing name, and (tries to) clear `h`.
The `clear` step fails if `h` has forward dependencies. In this case, the old `h`
will remain in the local context. The tactic returns the new hypothesis. -/
unsafe def replace_hyp (h : expr) (new_type : expr) (eq_pr : expr) (tag : Name := `unit.star) :
    tactic expr := do
  let h_type ← infer_type h
  let new_h ← assert h.local_pp_name new_type
  let eq_pr_type ← mk_app `eq [h_type, new_type]
  let eq_pr := mk_tagged_proof eq_pr_type eq_pr tag
  mk_eq_mp eq_pr h >>= exact
  try <| clear h
  return new_h
#align tactic.replace_hyp tactic.replace_hyp

unsafe def main_goal : tactic expr := do
  let g :: gs ← get_goals
  return g
#align tactic.main_goal tactic.main_goal

/-! Goal tagging support -/


unsafe def with_enable_tags {α : Type} (t : tactic α) (b := true) : tactic α := do
  let old ← tags_enabled
  enable_tags b
  let r ← t
  enable_tags old
  return r
#align tactic.with_enable_tags tactic.with_enable_tags

unsafe def get_main_tag : tactic Tag :=
  main_goal >>= get_tag
#align tactic.get_main_tag tactic.get_main_tag

unsafe def set_main_tag (t : Tag) : tactic Unit := do
  let g ← main_goal
  set_tag g t
#align tactic.set_main_tag tactic.set_main_tag

unsafe def subst (h : expr) : tactic Unit :=
  (do
      guard h
      let some (α, lhs, β, rhs) ← expr.is_heq <$> infer_type h
      is_def_eq α β
      let new_h_type ← mk_app `eq [lhs, rhs]
      let new_h_pr ← mk_app `eq_of_heq [h]
      let new_h ← assertv h.local_pp_name new_h_type new_h_pr
      try (clear h)
      subst_core new_h) <|>
    subst_core h
#align tactic.subst tactic.subst

end Tactic

open Tactic

namespace List

unsafe def for_each {α} : List α → (α → tactic Unit) → tactic Unit
  | [], fn => skip
  | e :: es, fn => do
    fn e
    for_each es fn
#align list.for_each list.for_each

unsafe def any_of {α β} : List α → (α → tactic β) → tactic β
  | [], fn => failed
  | e :: es, fn => do
    let opt_b ← try_core (fn e)
    match opt_b with
      | some b => return b
      | none => any_of es fn
#align list.any_of list.any_of

end List

/-! Install monad laws tactic and use it to prove some instances. -/


/-- Try to prove with `iff.refl`.-/
unsafe def order_laws_tac :=
  (whnf_target >> intros) >> to_expr ``(Iff.refl _) >>= exact
#align order_laws_tac order_laws_tac

unsafe def monad_from_pure_bind {m : Type u → Type v} (pure : ∀ {α : Type u}, α → m α)
    (bind : ∀ {α β : Type u}, m α → (α → m β) → m β) : Monad m
    where
  pure := @pure
  bind := @bind
#align monad_from_pure_bind monad_from_pure_bind

unsafe instance : Monad task where
  map := @task.map
  bind := @task.bind
  pure := @task.pure

namespace Tactic

unsafe def replace_target (new_target : expr) (pr : expr) (tag : Name := `unit.star) :
    tactic Unit := do
  let t ← target
  assert `htarget new_target
  swap
  let ht ← get_local `htarget
  let pr_type ← mk_app `eq [t, new_target]
  let locked_pr := mk_tagged_proof pr_type pr tag
  mk_eq_mpr locked_pr ht >>= exact
#align tactic.replace_target tactic.replace_target

unsafe def eval_pexpr (α) [reflected _ α] (e : pexpr) : tactic α :=
  to_expr ``(($(e) : $(reflect α))) false false >>= eval_expr α
#align tactic.eval_pexpr tactic.eval_pexpr

unsafe def run_simple {α} : tactic_state → tactic α → Option α
  | ts, t =>
    match t ts with
    | interaction_monad.result.success a ts' => some a
    | interaction_monad.result.exception _ _ _ => none
#align tactic.run_simple tactic.run_simple

end Tactic

