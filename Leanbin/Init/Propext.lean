/-
Copyright (c) 2016 Microsoft Corporation. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Leonardo de Moura
-/
prelude
import Leanbin.Init.Logic

#print propext /-
axiom propext {a b : Prop} : (a ↔ b) → a = b
-/

-- Additional congruence lemmas.
universe u v

#print forall_congr /-
theorem forall_congr {a : Sort u} {p q : a → Prop} (h : ∀ x, p x = q x) : (∀ x, p x) = ∀ x, q x :=
  propext (forall_congr' fun a => (h a).to_iff)
-/

#print imp_congr_eq /-
theorem imp_congr_eq {a b c d : Prop} (h₁ : a = c) (h₂ : b = d) : (a → b) = (c → d) :=
  propext (imp_congr h₁.to_iff h₂.to_iff)
-/

#print imp_congr_ctx_eq /-
theorem imp_congr_ctx_eq {a b c d : Prop} (h₁ : a = c) (h₂ : c → b = d) : (a → b) = (c → d) :=
  propext (imp_congr_ctx h₁.to_iff fun hc => (h₂ hc).to_iff)
-/

#print eq_true /-
theorem eq_true {a : Prop} (h : a) : a = True :=
  propext (iff_true_intro h)
-/

#print eq_false /-
theorem eq_false {a : Prop} (h : ¬a) : a = False :=
  propext (iff_false_intro h)
-/

#print Iff.to_eq /-
theorem Iff.to_eq {a b : Prop} (h : a ↔ b) : a = b :=
  propext h
-/

#print iff_eq_eq /-
theorem iff_eq_eq {a b : Prop} : (a ↔ b) = (a = b) :=
  propext (Iff.intro (fun h => Iff.to_eq h) fun h => h.to_iff)
-/

theorem eq_false_eq {a : Prop} : (a = False) = ¬a :=
  have : (a ↔ False) = ¬a := propext (iff_false_iff a)
  Eq.subst (@iff_eq_eq a False) this

theorem eq_true_eq {a : Prop} : (a = True) = a :=
  have : (a ↔ True) = a := propext (iff_true_iff a)
  Eq.subst (@iff_eq_eq a True) this

