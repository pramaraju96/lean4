/-
Copyright (c) 2014 Microsoft Corporation. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Floris van Doorn, Leonardo de Moura
-/
prelude
import init.relation init.num
import init.order

notation `ℕ` := nat

namespace nat

  inductive le (a : ℕ) : ℕ → Prop
  | nat_refl : le a    -- use nat_refl to avoid overloading le.refl
  | step : Π {b}, le b → le (succ b)

  instance : has_le ℕ :=
  ⟨nat.le⟩

  @[reducible] protected def lt (n m : ℕ) := succ n ≤ m

  instance : has_lt ℕ :=
  ⟨nat.lt⟩

  def pred : ℕ → ℕ
  | 0     := 0
  | (a+1) := a

  protected def sub : ℕ → ℕ → ℕ
  | a 0     := a
  | a (b+1) := pred (sub a b)

  protected def mul : nat → nat → nat
  | a 0     := 0
  | a (b+1) := (mul a b) + a

  instance : has_sub ℕ :=
  ⟨nat.sub⟩

  instance : has_mul ℕ :=
  ⟨nat.mul⟩

  instance : decidable_eq ℕ
  | zero     zero     := is_true rfl
  | (succ x) zero     := is_false (λ h, nat.no_confusion h)
  | zero     (succ y) := is_false (λ h, nat.no_confusion h)
  | (succ x) (succ y) :=
      match decidable_eq x y with
      | is_true xeqy := is_true (xeqy ▸ eq.refl (succ x))
      | is_false xney := is_false (λ h, nat.no_confusion h (λ xeqy, absurd xeqy xney))
      end

  def {u} repeat {α : Type u} (f : ℕ → α → α) : ℕ → α → α
  | 0         a := a
  | (succ n)  a := f n (repeat n a)

  instance : inhabited ℕ :=
  ⟨nat.zero⟩

  /- properties of inequality -/

  @[refl] protected def le_refl : ∀ a : ℕ, a ≤ a :=
  le.nat_refl

  lemma le_succ (n : ℕ) : n ≤ succ n :=
  le.step (nat.le_refl n)

  lemma succ_le_succ {n m : ℕ} : n ≤ m → succ n ≤ succ m :=
  λ h, le.rec (nat.le_refl (succ n)) (λ a b, le.step) h

  lemma zero_le : ∀ (n : ℕ), 0 ≤ n
  | 0     := nat.le_refl 0
  | (n+1) := le.step (zero_le n)

  lemma zero_lt_succ (n : ℕ) : 0 < succ n :=
  succ_le_succ (zero_le n)

  lemma not_succ_le_zero : ∀ (n : ℕ), succ n ≤ 0 → false
  .

  lemma not_lt_zero (a : ℕ) : ¬ a < 0 := not_succ_le_zero a

  lemma pred_le_pred {n m : ℕ} : n ≤ m → pred n ≤ pred m :=
  λ h, le.rec (nat.le_refl (pred n)) (λ n, nat.rec (λ a b, b) (λ a b c, le.step) n) h

  lemma le_of_succ_le_succ {n m : ℕ} : succ n ≤ succ m → n ≤ m :=
  pred_le_pred

  instance decidable_le : ∀ a b : ℕ, decidable (a ≤ b)
  | 0     b     := is_true (zero_le b)
  | (a+1) 0     := is_false (not_succ_le_zero a)
  | (a+1) (b+1) :=
    match decidable_le a b with
    | is_true h  := is_true (succ_le_succ h)
    | is_false h := is_false (λ a, h (le_of_succ_le_succ a))
    end

  instance decidable_lt : ∀ a b : ℕ, decidable (a < b) :=
  λ a b, nat.decidable_le (succ a) b

  protected lemma eq_or_lt_of_le {a b : ℕ} (h : a ≤ b) : a = b ∨ a < b :=
  le.cases_on h (or.inl rfl) (λ n h, or.inr (succ_le_succ h))

  lemma lt_succ_of_le {a b : ℕ} : a ≤ b → a < succ b :=
  succ_le_succ

  @[simp] lemma succ_sub_succ_eq_sub (a b : ℕ) : succ a - succ b = a - b :=
  nat.rec_on b
    (show succ a - succ zero = a - zero, from (eq.refl (succ a - succ zero)))
    (λ b, congr_arg pred)

  lemma not_succ_le_self : ∀ n : ℕ, ¬succ n ≤ n :=
  λ n, nat.rec (not_succ_le_zero 0) (λ a b c, b (le_of_succ_le_succ c)) n

  protected lemma lt_irrefl (n : ℕ) : ¬n < n :=
  not_succ_le_self n

  protected lemma le_trans {n m k : ℕ} (h1 : n ≤ m) : m ≤ k → n ≤ k :=
  le.rec h1 (λ p h2, le.step)

  lemma pred_le : ∀ (n : ℕ), pred n ≤ n
  | 0        := le.nat_refl 0
  | (succ a) := le.step (le.nat_refl a)

  lemma sub_le (a b : ℕ) : a - b ≤ a :=
  nat.rec_on b (nat.le_refl (a - 0)) (λ b₁, nat.le_trans (pred_le (a - b₁)))

  lemma sub_lt : ∀ {a b : ℕ}, 0 < a → 0 < b → a - b < a
  | 0     b     h1 h2 := absurd h1 (nat.lt_irrefl 0)
  | (a+1) 0     h1 h2 := absurd h2 (nat.lt_irrefl 0)
  | (a+1) (b+1) h1 h2 :=
    eq.symm (succ_sub_succ_eq_sub a b) ▸
      show a - b < succ a, from
      lt_succ_of_le (sub_le a b)

  protected lemma lt_of_lt_of_le {n m k : ℕ} : n < m → m ≤ k → n < k :=
  nat.le_trans

end nat
