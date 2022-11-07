/-
Copyright (c) 2016 Microsoft Corporation. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Leonardo de Moura
-/
prelude
import Leanbin.Init.Data.Nat.Basic

open Nat

@[reducible]
def IsValidChar (n : Nat) : Prop :=
  n < 55296 ∨ 57343 < n ∧ n < 1114112

theorem is_valid_char_range_1 (n : Nat) (h : n < 55296) : IsValidChar n :=
  Or.inl h

theorem is_valid_char_range_2 (n : Nat) (h₁ : 57343 < n) (h₂ : n < 1114112) : IsValidChar n :=
  Or.inr ⟨h₁, h₂⟩

#print Char /-
/-- The `char` type represents an unicode scalar value.
    See http://www.unicode.org/glossary/#unicode_scalar_value). -/
structure Char where
  val : Nat
  valid : IsValidChar val
-/

instance : SizeOf Char :=
  ⟨fun c => c.val⟩

namespace Char

protected def Lt (a b : Char) : Prop :=
  a.val < b.val

protected def Le (a b : Char) : Prop :=
  a.val ≤ b.val

instance : LT Char :=
  ⟨Char.Lt⟩

instance : LE Char :=
  ⟨Char.Le⟩

instance decidableLt (a b : Char) : Decidable (a < b) :=
  Nat.decidableLt _ _

instance decidableLe (a b : Char) : Decidable (a ≤ b) :=
  Nat.decidableLe _ _

/-
We cannot use tactics dec_trivial or comp_val here because the tactic framework has not been defined yet.
We also do not use `zero_lt_succ _` as a proof term because this proof may not be trivial to check by
external type checkers. See discussion at: https://github.com/leanprover/tc/issues/8
-/
theorem zero_lt_d800 : 0 < 55296 :=
  Nat.zero_lt_bit0 <|
    Nat.bit0_ne_zero <|
      Nat.bit0_ne_zero <|
        Nat.bit0_ne_zero <|
          Nat.bit0_ne_zero <|
            Nat.bit0_ne_zero <|
              Nat.bit0_ne_zero <|
                Nat.bit0_ne_zero <| Nat.bit0_ne_zero <| Nat.bit0_ne_zero <| Nat.bit0_ne_zero <| Nat.bit1_ne_zero 13

#print Char.ofNat /-
@[match_pattern]
def ofNat (n : Nat) : Char :=
  if h : IsValidChar n then { val := n, valid := h } else { val := 0, valid := Or.inl zero_lt_d800 }
-/

#print Char.toNat /-
def toNat (c : Char) : Nat :=
  c.val
-/

theorem eq_of_veq : ∀ {c d : Char}, c.val = d.val → c = d
  | ⟨v, h⟩, ⟨_, _⟩, rfl => rfl

theorem veq_of_eq : ∀ {c d : Char}, c = d → c.val = d.val
  | _, _, rfl => rfl

theorem ne_of_vne {c d : Char} (h : c.val ≠ d.val) : c ≠ d := fun h' => absurd (veq_of_eq h') h

theorem vne_of_ne {c d : Char} (h : c ≠ d) : c.val ≠ d.val := fun h' => absurd (eq_of_veq h') h

end Char

instance : DecidableEq Char := fun i j =>
  decidable_of_decidable_of_iff (Nat.decidableEq i.val j.val) ⟨Char.eq_of_veq, Char.veq_of_eq⟩

instance : Inhabited Char :=
  ⟨'A'⟩

