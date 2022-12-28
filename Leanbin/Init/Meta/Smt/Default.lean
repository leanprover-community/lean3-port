/-
Copyright (c) 2017 Microsoft Corporation. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Leonardo de Moura

! This file was ported from Lean 3 source module init.meta.smt.default
! leanprover-community/lean commit 855e5b74e3a52a40552e8f067169d747d48743fd
! Please do not edit these lines, except to modify the commit id
! if you have ported upstream changes.
-/
prelude
import Leanbin.Init.Meta.Smt.CongruenceClosure
import Leanbin.Init.CcLemmas
import Leanbin.Init.Meta.Smt.Ematch
import Leanbin.Init.Meta.Smt.SmtTactic
import Leanbin.Init.Meta.Smt.Interactive
import Leanbin.Init.Meta.Smt.Rsimp

