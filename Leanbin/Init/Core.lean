/-
Copyright (c) 2014 Microsoft Corporation. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Leonardo de Moura

notation, basic datatypes and type classes
-/
prelude

universe u v w

/-- The kernel definitional equality test (t =?= s) has special support for id_delta applications.
It implements the following rules

   1)   (id_delta t) =?= t
   2)   t =?= (id_delta t)
   3)   (id_delta t) =?= s  IF (unfold_of t) =?= s
   4)   t =?= id_delta s    IF t =?= (unfold_of s)

This is mechanism for controlling the delta reduction (aka unfolding) used in the kernel.

We use id_delta applications to address performance problems when type checking
lemmas generated by the equation compiler.
-/
@[inline]
def idDelta {α : Sort u} (a : α) : α :=
  a

/-- Gadget for optional parameter support. -/
@[reducible]
def optParam (α : Sort u) (default : α) : Sort u :=
  α

/-- Gadget for marking output parameters in type classes. -/
@[reducible]
def outParam (α : Sort u) : Sort u :=
  α

/-
  id_rhs is an auxiliary declaration used in the equation compiler to address performance
  issues when proving equational lemmas. The equation compiler uses it as a marker.
-/
abbrev idRhs (α : Sort u) (a : α) : α :=
  a

inductive PUnit : Sort u
  | star : PUnit

/-- An abbreviation for `punit.{0}`, its most common instantiation.
    This type should be preferred over `punit` where possible to avoid
    unnecessary universe parameters. -/
abbrev Unit : Type :=
  PUnit

@[matchPattern]
abbrev Unit.star : Unit :=
  PUnit.unit

/-- Gadget for defining thunks, thunk parameters have special treatment.
Example: given
      def f (s : string) (t : thunk nat) : nat
an application
     f "hello" 10
 is converted into
     f "hello" (λ _, 10)
-/
@[reducible]
def Thunkₓ (α : Type u) : Type u :=
  Unit → α

inductive True : Prop
  | intro : True

inductive False : Prop

inductive Empty : Type

/-- Logical not.

`not P`, with notation `¬ P`, is the `Prop` which is true if and only if `P` is false. It is
internally represented as `P → false`, so one way to prove a goal `⊢ ¬ P` is to use `intro h`,
which gives you a new hypothesis `h : P` and the goal `⊢ false`.

A hypothesis `h : ¬ P` can be used in term mode as a function, so if `w : P` then `h w : false`.

Related mathlib tactic: `contrapose`.
-/
def Not (a : Prop) :=
  a → False

-- ./././Mathport/Syntax/Translate/Command.lean:306:30: infer kinds are unsupported in Lean 4: refl []
inductive Eq {α : Sort u} (a : α) : α → Prop
  | refl : Eq a

/-
Initialize the quotient module, which effectively adds the following definitions:

constant quot {α : Sort u} (r : α → α → Prop) : Sort u

constant quot.mk {α : Sort u} (r : α → α → Prop) (a : α) : quot r

constant quot.lift {α : Sort u} {r : α → α → Prop} {β : Sort v} (f : α → β) :
  (∀ a b : α, r a b → eq (f a) (f b)) → quot r → β

constant quot.ind {α : Sort u} {r : α → α → Prop} {β : quot r → Prop} :
  (∀ a : α, β (quot.mk r a)) → ∀ q : quot r, β q

Also the reduction rule:

quot.lift f _ (quot.mk a) ~~> f a

-/
init_quot

-- ./././Mathport/Syntax/Translate/Command.lean:306:30: infer kinds are unsupported in Lean 4: refl []
/-- Heterogeneous equality.

Its purpose is to write down equalities between terms whose types are not definitionally equal.
For example, given `x : vector α n` and `y : vector α (0+n)`, `x = y` doesn't typecheck but `x == y` does.

If you have a goal `⊢ x == y`,
your first instinct should be to ask (either yourself, or on [zulip](https://leanprover.zulipchat.com/))
if something has gone wrong already.
If you really do need to follow this route,
you may find the lemmas `eq_rec_heq` and `eq_mpr_heq` useful.
-/
inductive HEq {α : Sort u} (a : α) : ∀ {β : Sort u}, β → Prop
  | refl : HEq a

structure Prod (α : Type u) (β : Type v) where
  fst : α
  snd : β

/-- Similar to `prod`, but α and β can be propositions.
   We use this type internally to automatically generate the brec_on recursor. -/
structure PProd (α : Sort u) (β : Sort v) where
  fst : α
  snd : β

/-- Logical and.

`and P Q`, with notation `P ∧ Q`, is the `Prop` which is true precisely when `P` and `Q` are
both true.

To prove a goal `⊢ P ∧ Q`, you can use the tactic `split`,
which gives two separate goals `⊢ P` and `⊢ Q`.

Given a hypothesis `h : P ∧ Q`, you can use the tactic `cases h with hP hQ`
to obtain two new hypotheses `hP : P` and `hQ : Q`. See also the `obtain` or `rcases` tactics in
mathlib.
-/
structure And (a b : Prop) : Prop where intro ::
  left : a
  right : b

theorem And.elim_left {a b : Prop} (h : And a b) : a :=
  h.1

theorem And.elim_right {a b : Prop} (h : And a b) : b :=
  h.2

-- eq basic support
attribute [refl] Eq.refl

-- This is a `def`, so that it can be used as pattern in the equation compiler.
@[matchPattern]
def rfl {α : Sort u} {a : α} : a = a :=
  Eq.refl a

@[elabAsElim, subst]
theorem Eq.subst {α : Sort u} {P : α → Prop} {a b : α} (h₁ : a = b) (h₂ : P a) : P b :=
  Eq.ndrec h₂ h₁

@[trans]
theorem Eq.trans {α : Sort u} {a b c : α} (h₁ : a = b) (h₂ : b = c) : a = c :=
  h₂ ▸ h₁

@[symm]
theorem Eq.symm {α : Sort u} {a b : α} (h : a = b) : b = a :=
  h ▸ rfl

-- This is a `def`, so that it can be used as pattern in the equation compiler.
@[matchPattern]
def HEq.rfl {α : Sort u} {a : α} : HEq a a :=
  HEq.refl a

theorem eq_of_heq {α : Sort u} {a a' : α} (h : HEq a a') : a = a' :=
  have : ∀ (α' : Sort u) (a' : α') (h₁ : @HEq α a α' a') (h₂ : α = α'), (Eq.recOnₓ h₂ a : α') = a' :=
    fun (α' : Sort u) (a' : α') (h₁ : @HEq α a α' a') => HEq.recOnₓ h₁ fun h₂ : α = α => rfl
  show (Eq.recOnₓ (Eq.refl α) a : α) = a' from this α a' h (Eq.refl α)

/- The following four lemmas could not be automatically generated when the
   structures were declared, so we prove them manually here. -/
theorem Prod.mk.inj {α : Type u} {β : Type v} {x₁ : α} {y₁ : β} {x₂ : α} {y₂ : β} :
    (x₁, y₁) = (x₂, y₂) → And (x₁ = x₂) (y₁ = y₂) := fun h => Prod.noConfusion h fun h₁ h₂ => ⟨h₁, h₂⟩

def Prod.mk.injArrow {α : Type u} {β : Type v} {x₁ : α} {y₁ : β} {x₂ : α} {y₂ : β} :
    (x₁, y₁) = (x₂, y₂) → ∀ ⦃P : Sort w⦄, (x₁ = x₂ → y₁ = y₂ → P) → P := fun h₁ _ h₂ => Prod.noConfusion h₁ h₂

theorem PProd.mk.inj {α : Sort u} {β : Sort v} {x₁ : α} {y₁ : β} {x₂ : α} {y₂ : β} :
    PProd.mk x₁ y₁ = PProd.mk x₂ y₂ → And (x₁ = x₂) (y₁ = y₂) := fun h => PProd.noConfusion h fun h₁ h₂ => ⟨h₁, h₂⟩

def PProd.mk.injArrow {α : Type u} {β : Type v} {x₁ : α} {y₁ : β} {x₂ : α} {y₂ : β} :
    (x₁, y₁) = (x₂, y₂) → ∀ ⦃P : Sort w⦄, (x₁ = x₂ → y₁ = y₂ → P) → P := fun h₁ _ h₂ => Prod.noConfusion h₁ h₂

inductive Sum (α : Type u) (β : Type v)
  | inl (val : α) : Sum
  | inr (val : β) : Sum

inductive PSum (α : Sort u) (β : Sort v)
  | inl (val : α) : PSum
  | inr (val : β) : PSum

/-- Logical or.

`or P Q`, with notation `P ∨ Q`, is the proposition which is true if and only if `P` or `Q` is
true.

To prove a goal `⊢ P ∨ Q`, if you know which alternative you want to prove,
you can use the tactics `left` (which gives the goal `⊢ P`)
or `right` (which gives the goal `⊢ Q`).

Given a hypothesis `h : P ∨ Q` and goal `⊢ R`,
the tactic `cases h` will give you two copies of the goal `⊢ R`,
with the hypothesis `h : P` in the first, and the hypothesis `h : Q` in the second.
-/
inductive Or (a b : Prop) : Prop
  | inl (h : a) : Or
  | inr (h : b) : Or

theorem Or.intro_left {a : Prop} (b : Prop) (ha : a) : Or a b :=
  Or.inl ha

theorem Or.intro_rightₓ (a : Prop) {b : Prop} (hb : b) : Or a b :=
  Or.inr hb

structure Sigma {α : Type u} (β : α → Type v) where mk ::
  fst : α
  snd : β fst

structure PSigma {α : Sort u} (β : α → Sort v) where mk ::
  fst : α
  snd : β fst

inductive Bool : Type
  | ff : Bool
  | tt : Bool

-- Remark: subtype must take a Sort instead of Type because of the axiom strong_indefinite_description.
structure Subtype {α : Sort u} (p : α → Prop) where
  val : α
  property : p val

attribute [pp_using_anonymous_constructor] Sigma PSigma Subtype PProd And

class inductive Decidable (p : Prop)
  | is_false (h : ¬p) : Decidable
  | is_true (h : p) : Decidable

@[reducible]
def DecidablePred {α : Sort u} (r : α → Prop) :=
  ∀ a : α, Decidable (r a)

@[reducible]
def DecidableRel {α : Sort u} (r : α → α → Prop) :=
  ∀ a b : α, Decidable (r a b)

@[reducible]
def DecidableEq (α : Sort u) :=
  DecidableRel (@Eq α)

inductive Option (α : Type u)
  | none : Option
  | some (val : α) : Option

export Option (none some)

export Bool (ff tt)

inductive List (T : Type u)
  | nil : List
  | cons (hd : T) (tl : List) : List

inductive Nat
  | zero : Nat
  | succ (n : Nat) : Nat

structure UnificationConstraint where
  {α : Type u}
  lhs : α
  rhs : α

structure UnificationHint where
  pattern : UnificationConstraint
  constraints : List UnificationConstraint

-- Declare builtin and reserved notation
class Zero (α : Type u) where
  zero : α

class One (α : Type u) where
  one : α

class Add (α : Type u) where
  add : α → α → α

class Mul (α : Type u) where
  mul : α → α → α

class Inv (α : Type u) where
  inv : α → α

class Neg (α : Type u) where
  neg : α → α

class Sub (α : Type u) where
  sub : α → α → α

class Div (α : Type u) where
  div : α → α → α

class Dvd (α : Type u) where
  Dvd : α → α → Prop

class Mod (α : Type u) where
  mod : α → α → α

class LE (α : Type u) where
  le : α → α → Prop

class LT (α : Type u) where
  lt : α → α → Prop

class Append (α : Type u) where
  append : α → α → α

class HasAndthen (α : Type u) (β : Type v) (σ : outParam <| Type w) where
  andthen : α → β → σ

class Union (α : Type u) where
  union : α → α → α

class Inter (α : Type u) where
  inter : α → α → α

class Sdiff (α : Type u) where
  sdiff : α → α → α

class HasEquivₓ (α : Sort u) where
  Equiv : α → α → Prop

class Subset (α : Type u) where
  Subset : α → α → Prop

class SSubset (α : Type u) where
  Ssubset : α → α → Prop

/-! Type classes `has_emptyc` and `has_insert` are
   used to implement polymorphic notation for collections.
   Example: `{a, b, c} = insert a (insert b (singleton c))`.    
   
   Note that we use `pair` in the name of lemmas about `{x, y} = insert x (singleton y)`. -/


class EmptyCollection (α : Type u) where
  emptyc : α

class Insert (α : outParam <| Type u) (γ : Type v) where
  insert : α → γ → γ

class Singleton (α : outParam <| Type u) (β : Type v) where
  singleton : α → β

-- Type class used to implement the notation { a ∈ c | p a }
class Sep (α : outParam <| Type u) (γ : Type v) where
  sep : (α → Prop) → γ → γ

-- Type class for set-like membership
class Membership (α : outParam <| Type u) (γ : Type v) where
  Mem : α → γ → Prop

class Pow (α : Type u) (β : Type v) where
  pow : α → β → α

export HasAndthen (andthen)

export Pow (pow)

-- mathport name: «expr ⊂ »
infixl:50
  " ⊂ " =>-- Note this is different to `|`.
  SSubset.Ssubset

export Append (append)

@[reducible]
def Ge {α : Type u} [LE α] (a b : α) : Prop :=
  LE.le b a

@[reducible]
def Gt {α : Type u} [LT α] (a b : α) : Prop :=
  LT.lt b a

@[reducible]
def Superset {α : Type u} [Subset α] (a b : α) : Prop :=
  Subset.Subset b a

@[reducible]
def Ssuperset {α : Type u} [SSubset α] (a b : α) : Prop :=
  SSubset.Ssubset b a

-- mathport name: «expr ⊇ »
infixl:50 " ⊇ " => Superset

-- mathport name: «expr ⊃ »
infixl:50 " ⊃ " => Ssuperset

def bit0 {α : Type u} [s : Add α] (a : α) : α :=
  a + a

def bit1 {α : Type u} [s₁ : One α] [s₂ : Add α] (a : α) : α :=
  bit0 a + 1

attribute [matchPattern] Zero.zero One.one bit0 bit1 Add.add Neg.neg Mul.mul

export Insert (insert)

class IsLawfulSingleton (α : Type u) (β : Type v) [EmptyCollection β] [Insert α β] [Singleton α β] : Prop where
  insert_emptyc_eq : ∀ x : α, (insert x ∅ : β) = {x}

export Singleton (singleton)

export IsLawfulSingleton (insert_emptyc_eq)

attribute [simp] insert_emptyc_eq

-- nat basic instances
namespace Nat

protected def add : Nat → Nat → Nat
  | a, zero => a
  | a, succ b => succ (add a b)

/- We mark the following definitions as pattern to make sure they can be used in recursive equations,
     and reduced by the equation compiler. -/
attribute [matchPattern] Nat.add Nat.add

end Nat

instance : Zero Nat :=
  ⟨Nat.zero⟩

instance : One Nat :=
  ⟨Nat.succ Nat.zero⟩

instance : Add Nat :=
  ⟨Nat.add⟩

def Std.Priority.default : Nat :=
  1000

def Std.Priority.max : Nat :=
  4294967295

namespace Nat

protected def prio :=
  Std.Priority.default + 100

end Nat

/-
  Global declarations of right binding strength

  If a module reassigns these, it will be incompatible with other modules that adhere to these
  conventions.

  When hovering over a symbol, use "C-c C-k" to see how to input it.
-/
def Std.Prec.max : Nat :=
  1024

-- the strength of application, identifiers, (, [, etc.
def Std.Prec.arrow : Nat :=
  25

/-
The next def is "max + 10". It can be used e.g. for postfix operations that should
be stronger than application.
-/
def Std.Prec.maxPlus : Nat :=
  Std.Prec.max + 10

-- input with \sy or \-1 or \inv
-- notation for n-ary tuples
-- sizeof
class SizeOf (α : Sort u) where
  sizeof : α → Nat

def sizeof {α : Sort u} [s : SizeOf α] : α → Nat :=
  SizeOf.sizeof

/-
Declare sizeof instances and lemmas for types declared before has_sizeof.
From now on, the inductive compiler will automatically generate sizeof instances and lemmas.
-/
-- Every type `α` has a default has_sizeof instance that just returns 0 for every element of `α`
protected def Default.sizeof (α : Sort u) : α → Nat
  | a => 0

instance defaultHasSizeof (α : Sort u) : SizeOf α :=
  ⟨Default.sizeof α⟩

protected def Nat.sizeof : Nat → Nat
  | n => n

instance : SizeOf Nat :=
  ⟨Nat.sizeof⟩

protected def Prod.sizeof {α : Type u} {β : Type v} [SizeOf α] [SizeOf β] : Prod α β → Nat
  | ⟨a, b⟩ => 1 + sizeof a + sizeof b

instance (α : Type u) (β : Type v) [SizeOf α] [SizeOf β] : SizeOf (Prod α β) :=
  ⟨Prod.sizeof⟩

protected def Sum.sizeof {α : Type u} {β : Type v} [SizeOf α] [SizeOf β] : Sum α β → Nat
  | Sum.inl a => 1 + sizeof a
  | Sum.inr b => 1 + sizeof b

instance (α : Type u) (β : Type v) [SizeOf α] [SizeOf β] : SizeOf (Sum α β) :=
  ⟨Sum.sizeof⟩

protected def PSum.sizeof {α : Type u} {β : Type v} [SizeOf α] [SizeOf β] : PSum α β → Nat
  | PSum.inl a => 1 + sizeof a
  | PSum.inr b => 1 + sizeof b

instance (α : Type u) (β : Type v) [SizeOf α] [SizeOf β] : SizeOf (PSum α β) :=
  ⟨PSum.sizeof⟩

protected def Sigma.sizeof {α : Type u} {β : α → Type v} [SizeOf α] [∀ a, SizeOf (β a)] : Sigma β → Nat
  | ⟨a, b⟩ => 1 + sizeof a + sizeof b

instance (α : Type u) (β : α → Type v) [SizeOf α] [∀ a, SizeOf (β a)] : SizeOf (Sigma β) :=
  ⟨Sigma.sizeof⟩

protected def PSigma.sizeof {α : Type u} {β : α → Type v} [SizeOf α] [∀ a, SizeOf (β a)] : PSigma β → Nat
  | ⟨a, b⟩ => 1 + sizeof a + sizeof b

instance (α : Type u) (β : α → Type v) [SizeOf α] [∀ a, SizeOf (β a)] : SizeOf (PSigma β) :=
  ⟨PSigma.sizeof⟩

protected def PUnit.sizeof : PUnit → Nat
  | u => 1

instance : SizeOf PUnit :=
  ⟨PUnit.sizeof⟩

protected def Bool.sizeof : Bool → Nat
  | b => 1

instance : SizeOf Bool :=
  ⟨Bool.sizeof⟩

protected def Option.sizeof {α : Type u} [SizeOf α] : Option α → Nat
  | none => 1
  | some a => 1 + sizeof a

instance (α : Type u) [SizeOf α] : SizeOf (Option α) :=
  ⟨Option.sizeof⟩

protected def List.sizeof {α : Type u} [SizeOf α] : List α → Nat
  | List.nil => 1
  | List.cons a l => 1 + sizeof a + List.sizeof l

instance (α : Type u) [SizeOf α] : SizeOf (List α) :=
  ⟨List.sizeof⟩

protected def Subtype.sizeof {α : Type u} [SizeOf α] {p : α → Prop} : Subtype p → Nat
  | ⟨a, _⟩ => sizeof a

instance {α : Type u} [SizeOf α] (p : α → Prop) : SizeOf (Subtype p) :=
  ⟨Subtype.sizeof⟩

theorem nat_add_zero (n : Nat) : n + 0 = n :=
  rfl

-- Combinator calculus
namespace Combinator

universe u₁ u₂ u₃

def i {α : Type u₁} (a : α) :=
  a

def k {α : Type u₁} {β : Type u₂} (a : α) (b : β) :=
  a

def s {α : Type u₁} {β : Type u₂} {γ : Type u₃} (x : α → β → γ) (y : α → β) (z : α) :=
  x z (y z)

end Combinator

/-- Auxiliary datatype for #[ ... ] notation.
    #[1, 2, 3, 4] is notation for

    bin_tree.node
      (bin_tree.node (bin_tree.leaf 1) (bin_tree.leaf 2))
      (bin_tree.node (bin_tree.leaf 3) (bin_tree.leaf 4))

    We use this notation to input long sequences without exhausting the system stack space.
    Later, we define a coercion from `bin_tree` into `list`.
-/
inductive BinTree (α : Type u)
  | Empty : BinTree
  | leaf (val : α) : BinTree
  | node (left right : BinTree) : BinTree

attribute [elabWithoutExpectedType] BinTree.node BinTree.leaf

/-- Like `by apply_instance`, but not dependent on the tactic framework. -/
@[reducible]
def inferInstance {α : Sort u} [i : α] : α :=
  i

