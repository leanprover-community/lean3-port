/-
Copyright (c) 2014 Microsoft Corporation. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Leonardo de Moura, Jeremy Avigad, Floris van Doorn
-/
prelude
import Leanbin.Init.Logic
import Leanbin.Init.Wf

-- mathport name: «exprΣ , »
notation3"Σ "(...)", "r:(scoped p => Sigma p) => r

-- mathport name: «exprΣ' , »
notation3"Σ' "(...)", "r:(scoped p => PSigma p) => r

universe u v

theorem ex_of_psig {α : Type u} {p : α → Prop} : (Σ' x, p x) → ∃ x, p x
  | ⟨x, hx⟩ => ⟨x, hx⟩
#align ex_of_psig ex_of_psig

section

variable {α : Type u} {β : α → Type v}

protected theorem Sigma.eq : ∀ {p₁ p₂ : Σ a : α, β a} (h₁ : p₁.1 = p₂.1), (Eq.recOn h₁ p₁.2 : β p₂.1) = p₂.2 → p₁ = p₂
  | ⟨a, b⟩, ⟨a, b⟩, rfl, rfl => rfl
#align sigma.eq Sigma.eq

end

section

variable {α : Sort u} {β : α → Sort v}

protected theorem PSigma.eq : ∀ {p₁ p₂ : PSigma β} (h₁ : p₁.1 = p₂.1), (Eq.recOn h₁ p₁.2 : β p₂.1) = p₂.2 → p₁ = p₂
  | ⟨a, b⟩, ⟨a, b⟩, rfl, rfl => rfl
#align psigma.eq PSigma.eq

end

