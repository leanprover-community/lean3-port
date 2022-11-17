/-
Copyright (c) 2017 Mario Carneiro. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Mario Carneiro
-/
prelude
import Leanbin.Init.Data.Int.Basic
import Leanbin.Init.Data.Nat.Bitwise

universe u

namespace Int

def div2 : ℤ → ℤ
  | of_nat n => n.div2
  | -[1+ n] => -[1+ n.div2]
#align int.div2 Int.div2

def bodd : ℤ → Bool
  | of_nat n => n.bodd
  | -[1+ n] => not n.bodd
#align int.bodd Int.bodd

def bit (b : Bool) : ℤ → ℤ :=
  cond b bit1 bit0
#align int.bit Int.bit

def testBit : ℤ → ℕ → Bool
  | (m : ℕ), n => Nat.testBit m n
  | -[1+ m], n => not (Nat.testBit m n)
#align int.test_bit Int.testBit

def natBitwise (f : Bool → Bool → Bool) (m n : ℕ) : ℤ :=
  cond (f false false) -[1+ Nat.bitwise (fun x y => not (f x y)) m n] (Nat.bitwise f m n)
#align int.nat_bitwise Int.natBitwise

def bitwise (f : Bool → Bool → Bool) : ℤ → ℤ → ℤ
  | (m : ℕ), (n : ℕ) => natBitwise f m n
  | (m : ℕ), -[1+ n] => natBitwise (fun x y => f x (not y)) m n
  | -[1+ m], (n : ℕ) => natBitwise (fun x y => f (not x) y) m n
  | -[1+ m], -[1+ n] => natBitwise (fun x y => f (not x) (not y)) m n
#align int.bitwise Int.bitwise

def lnot : ℤ → ℤ
  | (m : ℕ) => -[1+ m]
  | -[1+ m] => m
#align int.lnot Int.lnot

def lor : ℤ → ℤ → ℤ
  | (m : ℕ), (n : ℕ) => Nat.lor m n
  | (m : ℕ), -[1+ n] => -[1+ Nat.ldiff n m]
  | -[1+ m], (n : ℕ) => -[1+ Nat.ldiff m n]
  | -[1+ m], -[1+ n] => -[1+ Nat.land m n]
#align int.lor Int.lor

def land : ℤ → ℤ → ℤ
  | (m : ℕ), (n : ℕ) => Nat.land m n
  | (m : ℕ), -[1+ n] => Nat.ldiff m n
  | -[1+ m], (n : ℕ) => Nat.ldiff n m
  | -[1+ m], -[1+ n] => -[1+ Nat.lor m n]
#align int.land Int.land

def ldiff : ℤ → ℤ → ℤ
  | (m : ℕ), (n : ℕ) => Nat.ldiff m n
  | (m : ℕ), -[1+ n] => Nat.land m n
  | -[1+ m], (n : ℕ) => -[1+ Nat.lor m n]
  | -[1+ m], -[1+ n] => Nat.ldiff n m
#align int.ldiff Int.ldiff

def lxor : ℤ → ℤ → ℤ
  | (m : ℕ), (n : ℕ) => Nat.lxor m n
  | (m : ℕ), -[1+ n] => -[1+ Nat.lxor m n]
  | -[1+ m], (n : ℕ) => -[1+ Nat.lxor m n]
  | -[1+ m], -[1+ n] => Nat.lxor m n
#align int.lxor Int.lxor

def shiftl : ℤ → ℤ → ℤ
  | (m : ℕ), (n : ℕ) => Nat.shiftl m n
  | (m : ℕ), -[1+ n] => Nat.shiftr m (Nat.succ n)
  | -[1+ m], (n : ℕ) => -[1+ Nat.shiftl' true m n]
  | -[1+ m], -[1+ n] => -[1+ Nat.shiftr m (Nat.succ n)]
#align int.shiftl Int.shiftl

def shiftr (m n : ℤ) : ℤ :=
  shiftl m (-n)
#align int.shiftr Int.shiftr

end Int

