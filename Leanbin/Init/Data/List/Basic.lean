/-
Copyright (c) 2016 Microsoft Corporation. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Leonardo de Moura
-/
prelude
import Leanbin.Init.Logic
import Leanbin.Init.Data.Nat.Basic
import Leanbin.Init.Data.Bool.Basic
import Leanbin.Init.Propext

open Decidable List

universe u v w

instance (α : Type u) : Inhabited (List α) :=
  ⟨List.nil⟩

variable {α : Type u} {β : Type v} {γ : Type w}

namespace List

#print List.hasDecEq /-
protected def hasDecEq [s : DecidableEq α] : DecidableEq (List α)
  | [], [] => isTrue rfl
  | a :: as, [] => isFalse fun h => List.noConfusion h
  | [], b :: bs => isFalse fun h => List.noConfusion h
  | a :: as, b :: bs =>
    match s a b with
    | is_true hab =>
      match has_dec_eq as bs with
      | is_true habs => isTrue (Eq.subst hab (Eq.subst habs rfl))
      | is_false nabs => isFalse fun h => List.noConfusion h fun _ habs => absurd habs nabs
    | is_false nab => isFalse fun h => List.noConfusion h fun hab _ => absurd hab nab
-/

instance [DecidableEq α] : DecidableEq (List α) :=
  List.hasDecEq

#print List.append /-
@[simp]
protected def append : List α → List α → List α
  | [], l => l
  | h :: s, t => h :: append s t
-/

instance : Append (List α) :=
  ⟨List.append⟩

#print List.Mem /-
protected def Mem : α → List α → Prop
  | a, [] => False
  | a, b :: l => a = b ∨ mem a l
-/

instance : Membership α (List α) :=
  ⟨List.Mem⟩

instance decidableMem [DecidableEq α] (a : α) : ∀ l : List α, Decidable (a ∈ l)
  | [] => isFalse not_false
  | b :: l =>
    if h₁ : a = b then isTrue (Or.inl h₁)
    else
      match decidable_mem l with
      | is_true h₂ => isTrue (Or.inr h₂)
      | is_false h₂ => isFalse (not_or_of_not h₁ h₂)

instance : EmptyCollection (List α) :=
  ⟨List.nil⟩

protected def erase' {α} [DecidableEq α] : List α → α → List α
  | [], b => []
  | a :: l, b => if a = b then l else a :: erase l b

protected def bagInter' {α} [DecidableEq α] : List α → List α → List α
  | [], _ => []
  | _, [] => []
  | a :: l₁, l₂ => if a ∈ l₂ then a :: bag_inter l₁ (l₂.erase a) else bag_inter l₁ l₂

protected def diff' {α} [DecidableEq α] : List α → List α → List α
  | l, [] => l
  | l₁, a :: l₂ => if a ∈ l₁ then diff (l₁.erase a) l₂ else diff l₁ l₂

#print List.length /-
@[simp]
def length : List α → Nat
  | [] => 0
  | a :: l => length l + 1
-/

def empty : List α → Bool
  | [] => true
  | _ :: _ => false

open Option Nat

@[simp]
def nth : List α → Nat → Option α
  | [], n => none
  | a :: l, 0 => some a
  | a :: l, n + 1 => nth l n

@[simp]
def nthLe : ∀ (l : List α) (n), n < l.length → α
  | [], n, h => absurd h n.not_lt_zero
  | a :: l, 0, h => a
  | a :: l, n + 1, h => nth_le l n (le_of_succ_le_succ h)

@[simp]
def head' [Inhabited α] : List α → α
  | [] => default
  | a :: l => a

#print List.tail /-
@[simp]
def tail : List α → List α
  | [] => []
  | a :: l => l
-/

def reverseCore : List α → List α → List α
  | [], r => r
  | a :: l, r => reverse_core l (a :: r)

#print List.reverse /-
def reverse : List α → List α := fun l => reverseCore l []
-/

#print List.map /-
@[simp]
def map (f : α → β) : List α → List β
  | [] => []
  | a :: l => f a :: map l
-/

@[simp]
def map₂ (f : α → β → γ) : List α → List β → List γ
  | [], _ => []
  | _, [] => []
  | x :: xs, y :: ys => f x y :: map₂ xs ys

def mapWithIndexCore (f : ℕ → α → β) : ℕ → List α → List β
  | k, [] => []
  | k, a :: as => f k a :: map_with_index_core (k + 1) as

/-- Given a function `f : ℕ → α → β` and `as : list α`, `as = [a₀, a₁, ...]`, returns the list
`[f 0 a₀, f 1 a₁, ...]`. -/
def mapWithIndex (f : ℕ → α → β) (as : List α) : List β :=
  mapWithIndexCore f 0 as

#print List.join /-
def join : List (List α) → List α
  | [] => []
  | l :: ls => l ++ join ls
-/

#print List.filterMap /-
def filterMap (f : α → Option β) : List α → List β
  | [] => []
  | a :: l =>
    match f a with
    | none => filter_map l
    | some b => b :: filter_map l
-/

def filter' (p : α → Prop) [DecidablePred p] : List α → List α
  | [] => []
  | a :: l => if p a then a :: filter l else filter l

def partition' (p : α → Prop) [DecidablePred p] : List α → List α × List α
  | [] => ([], [])
  | a :: l =>
    let (l₁, l₂) := partition l
    if p a then (a :: l₁, l₂) else (l₁, a :: l₂)

def dropWhile' (p : α → Prop) [DecidablePred p] : List α → List α
  | [] => []
  | a :: l => if p a then drop_while l else a :: l

/-- `after p xs` is the suffix of `xs` after the first element that satisfies
  `p`, not including that element.

  ```lean
  after      (eq 1)       [0, 1, 2, 3] = [2, 3]
  drop_while (not ∘ eq 1) [0, 1, 2, 3] = [1, 2, 3]
  ```
-/
def after' (p : α → Prop) [DecidablePred p] : List α → List α
  | [] => []
  | x :: xs => if p x then xs else after xs

def span' (p : α → Prop) [DecidablePred p] : List α → List α × List α
  | [] => ([], [])
  | a :: xs =>
    if p a then
      let (l, r) := span xs
      (a :: l, r)
    else ([], a :: xs)

def findIndex (p : α → Prop) [DecidablePred p] : List α → Nat
  | [] => 0
  | a :: l => if p a then 0 else succ (find_index l)

def indexOf' [DecidableEq α] (a : α) : List α → Nat :=
  findIndex (Eq a)

def removeAll' [DecidableEq α] (xs ys : List α) : List α :=
  filter' (· ∉ ys) xs

def updateNth : List α → ℕ → α → List α
  | x :: xs, 0, a => a :: xs
  | x :: xs, i + 1, a => x :: update_nth xs i a
  | [], _, _ => []

#print List.removeNth /-
def removeNth : List α → ℕ → List α
  | [], _ => []
  | x :: xs, 0 => xs
  | x :: xs, i + 1 => x :: remove_nth xs i
-/

#print List.drop /-
@[simp]
def drop : ℕ → List α → List α
  | 0, a => a
  | succ n, [] => []
  | succ n, x :: r => drop n r
-/

#print List.take /-
@[simp]
def take : ℕ → List α → List α
  | 0, a => []
  | succ n, [] => []
  | succ n, x :: r => x :: take n r
-/

#print List.foldl /-
@[simp]
def foldl (f : α → β → α) : α → List β → α
  | a, [] => a
  | a, b :: l => foldl (f a b) l
-/

#print List.foldr /-
@[simp]
def foldr (f : α → β → β) (b : β) : List α → β
  | [] => b
  | a :: l => f a (foldr l)
-/

#print List.any /-
def any (l : List α) (p : α → Bool) : Bool :=
  foldr (fun a r => p a || r) false l
-/

#print List.all /-
def all (l : List α) (p : α → Bool) : Bool :=
  foldr (fun a r => p a && r) true l
-/

def bor (l : List Bool) : Bool :=
  any l id

def band (l : List Bool) : Bool :=
  all l id

#print List.zipWith /-
def zipWith (f : α → β → γ) : List α → List β → List γ
  | x :: xs, y :: ys => f x y :: zip_with xs ys
  | _, _ => []
-/

#print List.zip /-
def zip : List α → List β → List (Prod α β) :=
  zipWith Prod.mk
-/

#print List.unzip /-
def unzip : List (α × β) → List α × List β
  | [] => ([], [])
  | (a, b) :: t =>
    match unzip t with
    | (al, bl) => (a :: al, b :: bl)
-/

#print List.insert /-
protected def insert [DecidableEq α] (a : α) (l : List α) : List α :=
  if a ∈ l then l else a :: l
-/

instance [DecidableEq α] : Insert α (List α) :=
  ⟨List.insert⟩

instance : Singleton α (List α) :=
  ⟨fun x => [x]⟩

instance [DecidableEq α] : LawfulSingleton α (List α) :=
  ⟨fun x => show (if x ∈ ([] : List α) then [] else [x]) = [x] from if_neg not_false⟩

#print List.union /-
protected def union [DecidableEq α] (l₁ l₂ : List α) : List α :=
  foldr insert l₂ l₁
-/

instance [DecidableEq α] : Union (List α) :=
  ⟨List.union⟩

#print List.inter /-
protected def inter [DecidableEq α] (l₁ l₂ : List α) : List α :=
  filter' (· ∈ l₂) l₁
-/

instance [DecidableEq α] : Inter (List α) :=
  ⟨List.inter⟩

@[simp]
def repeat (a : α) : ℕ → List α
  | 0 => []
  | succ n => a :: repeat n

def rangeCore : ℕ → List ℕ → List ℕ
  | 0, l => l
  | succ n, l => range_core n (n :: l)

#print List.range /-
def range (n : ℕ) : List ℕ :=
  rangeCore n []
-/

#print List.iota /-
def iota : ℕ → List ℕ
  | 0 => []
  | succ n => succ n :: iota n
-/

#print List.enumFrom /-
def enumFrom : ℕ → List α → List (ℕ × α)
  | n, [] => nil
  | n, x :: xs => (n, x) :: enum_from (n + 1) xs
-/

#print List.enum /-
def enum : List α → List (ℕ × α) :=
  enumFrom 0
-/

@[simp]
def last : ∀ l : List α, l ≠ [] → α
  | [], h => absurd rfl h
  | [a], h => a
  | a :: b :: l, h => last (b :: l) fun h => List.noConfusion h

def ilast [Inhabited α] : List α → α
  | [] => Inhabited.default α
  | [a] => a
  | [a, b] => b
  | a :: b :: l => ilast l

def init : List α → List α
  | [] => []
  | [a] => []
  | a :: l => a :: init l

#print List.intersperse /-
def intersperse (sep : α) : List α → List α
  | [] => []
  | [x] => [x]
  | x :: xs => x :: sep :: intersperse xs
-/

#print List.intercalate /-
def intercalate (sep : List α) (xs : List (List α)) : List α :=
  join (intersperse sep xs)
-/

#print List.bind /-
@[inline]
protected def bind {α : Type u} {β : Type v} (a : List α) (b : α → List β) : List β :=
  join (map b a)
-/

@[inline]
protected def ret {α : Type u} (a : α) : List α :=
  [a]

#print List.lt /-
protected def lt [LT α] : List α → List α → Prop
  | [], [] => False
  | [], b :: bs => True
  | a :: as, [] => False
  | a :: as, b :: bs => a < b ∨ ¬b < a ∧ lt as bs
-/

instance [LT α] : LT (List α) :=
  ⟨List.lt⟩

#print List.hasDecidableLt /-
instance hasDecidableLt [LT α] [h : DecidableRel ((· < ·) : α → α → Prop)] : ∀ l₁ l₂ : List α, Decidable (l₁ < l₂)
  | [], [] => isFalse not_false
  | [], b :: bs => isTrue trivial
  | a :: as, [] => isFalse not_false
  | a :: as, b :: bs =>
    match h a b with
    | is_true h₁ => isTrue (Or.inl h₁)
    | is_false h₁ =>
      match h b a with
      | is_true h₂ => isFalse fun h => Or.elim h (fun h => absurd h h₁) fun ⟨h, _⟩ => absurd h₂ h
      | is_false h₂ =>
        match has_decidable_lt as bs with
        | is_true h₃ => isTrue (Or.inr ⟨h₂, h₃⟩)
        | is_false h₃ => isFalse fun h => Or.elim h (fun h => absurd h h₁) fun ⟨_, h⟩ => absurd h h₃
-/

@[reducible]
protected def Le [LT α] (a b : List α) : Prop :=
  ¬b < a

instance [LT α] : LE (List α) :=
  ⟨List.Le⟩

instance hasDecidableLe [LT α] [h : DecidableRel ((· < ·) : α → α → Prop)] : ∀ l₁ l₂ : List α, Decidable (l₁ ≤ l₂) :=
  fun a b => Not.decidable

theorem le_eq_not_gt [LT α] : ∀ l₁ l₂ : List α, (l₁ ≤ l₂) = ¬l₂ < l₁ := fun l₁ l₂ => rfl

theorem lt_eq_not_ge [LT α] [DecidableRel ((· < ·) : α → α → Prop)] : ∀ l₁ l₂ : List α, (l₁ < l₂) = ¬l₂ ≤ l₁ :=
  fun l₁ l₂ => show (l₁ < l₂) = ¬¬l₁ < l₂ from Eq.subst (propext (not_not_iff (l₁ < l₂))).symm rfl

/-- `is_prefix_of l₁ l₂` returns `tt` iff `l₁` is a prefix of `l₂`. -/
def isPrefixOf' [DecidableEq α] : List α → List α → Bool
  | [], _ => true
  | _, [] => false
  | a :: as, b :: bs => decide (a = b) && is_prefix_of as bs

/-- `is_suffix_of l₁ l₂` returns `tt` iff `l₁` is a suffix of `l₂`. -/
def isSuffixOf' [DecidableEq α] (l₁ l₂ : List α) : Bool :=
  isPrefixOf' l₁.reverse l₂.reverse

end List

namespace BinTree

private def to_list_aux : BinTree α → List α → List α
  | Empty, as => as
  | leaf a, as => a :: as
  | node l r, as => to_list_aux l (to_list_aux r as)

def toList (t : BinTree α) : List α :=
  toListAux t []

end BinTree

