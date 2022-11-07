/-
Copyright (c) 2014 Microsoft Corporation. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Leonardo de Moura
-/
prelude
import Leanbin.Init.Core

/-!
# Boolean operations
-/


#print cond /-
/-- `cond b x y` is `x` if `b = tt` and `y` otherwise. -/
@[inline]
def cond.{u} {a : Type u} : Bool → a → a → a
  | tt, x, y => x
  | ff, x, y => y
-/

#print or /-
/-- Boolean OR -/
@[inline]
def or : Bool → Bool → Bool
  | tt, b => true
  | ff, b => b
-/

#print and /-
/-- Boolean AND -/
@[inline]
def and : Bool → Bool → Bool
  | tt, b => b
  | ff, b => false
-/

#print not /-
/-- Boolean NOT -/
@[inline]
def not : Bool → Bool
  | tt => false
  | ff => true
-/

#print xor /-
/-- Boolean XOR -/
@[inline]
def xor : Bool → Bool → Bool
  | tt, ff => true
  | ff, tt => true
  | _, _ => false
-/

