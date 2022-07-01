{-# OPTIONS --rewriting --prop #-}

module Lambda where

open import Agda.Primitive
open import Agda.Builtin.Equality
open import Agda.Builtin.Equality.Rewrite
open import Relation.Binary.PropositionalEquality
open import Data.Empty
open import Data.Unit
open import Data.Sum
open import Data.Product
open import Data.Fin
open import Data.Vec
open import Data.Nat

{-

This file describes the syntax of λ terms with higher-order abstract syntax and
its associated elimination principles.  We begin by postulating the existence of
a type Λ for classifying λ terms.  This type comes with two constructors _·_ and
ƛ_, which correspond to application and λ abstraction.  To make the definition
more convenient to work with, the definition uses an auxiliary data type Λ' that
injects into Λ via the function ⟨_⟩.  This allows us to reason about these
constructors as if they came from a regular Agda data type.

-}

infixl 7 _·_
infix 6 ƛ_

postulate Λ : Set

module Internal where

  data Λ' : Set where
    _·_ : Λ → Λ → Λ'
    ƛ_ : (Λ → Λ) → Λ'

postulate ⟨_⟩ : Internal.Λ' → Λ
{-# INJECTIVE ⟨_⟩ #-}

_·_ : Λ → Λ → Λ
t1 · t2 = ⟨ Internal._·_ t1 t2 ⟩

ƛ_ : (Λ → Λ) → Λ
ƛ_ t = ⟨ Internal.ƛ t ⟩

{-

To illustrate this last point, here is how we can show that _·_ is injective and
disjoint from ƛ_, using just regular equality reasoning.

-}

·-injective : (t₁ t₂ t₁' t₂' : Λ) → t₁ · t₂ ≡ t₁' · t₂' →
  (t₁ ≡ t₁') × (t₂ ≡ t₂')
·-injective t₁ t₂ .t₁ .t₂ refl = ( refl , refl )

·-ƛ-disjoint : (t₁ t₂ : Λ) (t : Λ → Λ) → t₁ · t₂ ≡ ƛ t → ⊥
·-ƛ-disjoint t₁ t₂ t ()

{-

Our constructors have one important difference compared to usual Agda
constructors: it is not possible to perform case analysis on them (essentially,
because we cannot test whether a term was built using ⟨_⟩.)  Thus, we also need
to postulate a case-analysis principle for Λ.

To do this soundly, we need to use Agda's @♭ modality.  Roughly speaking, terms
that are not associated with the @♭ modality can depend on @♭ terms, but not the
other way around.  Agda does not do much with this modality by itself.  The
modality can appear in the definition of function arguments, but it does not
have any intrinsic meaning.  It is our job to decide ultimately what it
means. Here, we'll interpret a @♭ variable of type T as referring to a value of
T that does not contain any free variables of type Λ.

(You might be wondering why this makes sense. The @♭ modality is inspired by
Mike Shulman's spatial type theory, which has a variety of models.

-}

Ctx : Set
Ctx = ℕ

C⟦_⟧ : Ctx → Set
C⟦ zero ⟧ = ⊤
C⟦ suc Γ ⟧ = Λ × C⟦ Γ ⟧

Var : Ctx → Set
Var = Fin

abs : {Γ : ℕ} → (C⟦ Γ ⟧ → Λ → Λ) → C⟦ suc Γ ⟧ → Λ
abs t γ = t (proj₂ γ) (proj₁ γ)

V⟦_⟧ : {Γ : ℕ} → Var Γ → C⟦ Γ ⟧ → Λ
V⟦ zero ⟧ = proj₁
V⟦ suc x ⟧ = λ γ → V⟦ x ⟧ (proj₂ γ)


postulate
  Λ-elim : {l : Level}
    (A : ∀ (@♭ Γ) → @♭ (C⟦ Γ ⟧ → Λ) → Set l) →
    (HV : ∀ (@♭ Γ) (@♭ v : Var Γ) → A Γ V⟦ v ⟧) →
    (Hƛ : ∀ (@♭ Γ) (@♭ t : C⟦ Γ ⟧ → Λ → Λ) → A (suc Γ) (abs t) →
      A Γ (λ γ → ƛ (t γ))) →
    (H· : ∀ (@♭ Γ) (@♭ t1 t2 : C⟦ Γ ⟧ → Λ) →
      A Γ t1 → A Γ t2 → A Γ (λ γ → t1 γ · t2 γ)) →
    ∀ (@♭ Γ) (@♭ t : C⟦ Γ ⟧ → Λ) → A Γ t


postulate
  Λ-elim-V :
    ∀ {l : Level} A HV Hƛ H· →
    ∀ (@♭ Γ)  (@♭ v : Var Γ) →
    Λ-elim {l} A HV Hƛ H· Γ V⟦ v ⟧ ≡ HV Γ v

postulate
  Λ-elim-ƛ :
    ∀ {l : Level} A HV Hƛ H· →
    ∀ (@♭ Γ) (@♭ t : C⟦ Γ ⟧ → Λ → Λ) →
    Λ-elim {l} A HV Hƛ H· Γ (λ γ → ƛ (t γ)) ≡
    Hƛ Γ t (Λ-elim A HV Hƛ H· (suc Γ) (abs t))

postulate
  Λ-elim-· :
    ∀ {l : Level} A HV Hƛ H· →
    ∀ (@♭ Γ) (@♭ t1 t2 : C⟦ Γ ⟧ → Λ) →
    Λ-elim {l} A HV Hƛ H· Γ (λ γ → t1 γ · t2 γ) ≡
    H· Γ t1 t2 (Λ-elim A HV Hƛ H· Γ t1) (Λ-elim A HV Hƛ H· Γ t2)

{-# REWRITE Λ-elim-V #-}
{-# REWRITE Λ-elim-ƛ #-}
{-# REWRITE Λ-elim-· #-}

Λ-cong1 :
  ∀ {l  : Level} →
  ∀ (A  : Λ → Set l) →
  ∀ (Hƛ : ∀ (t : Λ → Λ) → (∀ x → A x → A (t x)) → A (ƛ t)) →
  ∀ (H· : ∀ t1 t2 → A t1 → A t2 → A (t1 · t2)) →
  ∀ {@♭ Γ} (@♭ t : C⟦ Γ ⟧ → Λ) →
  ∀ γ → (∀ (v : Var Γ) → A (V⟦ v ⟧ γ)) → A (t γ)
Λ-cong1 {l} A Hƛ H· t = Λ-elim A' HV' Hƛ' H·' _ t
  where
  A' : ∀ (@♭ Γ) (@♭ A : C⟦ Γ ⟧ → Λ) → Set l
  A' Γ t = ∀ γ → (∀ (v : Var Γ) → A (V⟦ v ⟧ γ)) → A (t γ)

  HV' : _
  HV' Γ x γ A-γ = A-γ x

  Hƛ' : _
  Hƛ' Γ t IH γ A-γ = Hƛ (t γ) (λ x A-x → IH (x , γ) (A-γ' x A-x))
    where
    A-γ' : ∀ x → A x → ∀ (v : Var (suc Γ)) → A (V⟦ v ⟧ (x , γ))
    A-γ' x A-x zero = A-x
    A-γ' x A-x (suc v) = A-γ v

  H·' : _
  H·' Γ t1 t2 IH1 IH2 γ A-γ = H· _ _ (IH1 γ A-γ) (IH2 γ A-γ)

Λ-cong2 :
  ∀ {l  : Level} →
  ∀ (A  : Λ → Λ → Set l) →
  ∀ (Hƛ : ∀ (t1 t2 : Λ → Λ) →
          (∀ x → A x x → A (t1 x) (t2 x)) → A (ƛ t1) (ƛ t2)) →
  ∀ (H· : ∀ t11 t12 t21 t22 → A t11 t21 → A t12 t22 →
          A (t11 · t12) (t21 · t22)) →
  ∀ {@♭ Γ} (@♭ t : C⟦ Γ ⟧ → Λ) →
  ∀ γ1 γ2 → (∀ (v : Var Γ) → A (V⟦ v ⟧ γ1) (V⟦ v ⟧ γ2)) → A (t γ1) (t γ2)
Λ-cong2 {l} A Hƛ H· t = Λ-elim A' HV' Hƛ' H·' _ t
  where
  A' : ∀ (@♭ Γ) (@♭ A : C⟦ Γ ⟧ → Λ) → Set l
  A' Γ t = ∀ γ1 γ2 → (∀ (v : Var Γ) → A (V⟦ v ⟧ γ1) (V⟦ v ⟧ γ2)) →
           A (t γ1) (t γ2)

  HV' : _
  HV' Γ x γ1 γ2 A-γ = A-γ x

  Hƛ' : _
  Hƛ' Γ t IH γ1 γ2 A-γ = Hƛ (t γ1) (t γ2)
    (λ x A-x → IH (x , γ1) (x , γ2) (A-γ' x A-x))
    where
    A-γ' : ∀ x → A x x → ∀ (v : Var (suc Γ)) →
           A (V⟦ v ⟧ (x , γ1)) (V⟦ v ⟧ (x , γ2))
    A-γ' x A-x zero = A-x
    A-γ' x A-x (suc v) = A-γ v

  H·' : _
  H·' Γ t1 t2 IH1 IH2 γ1 γ2 A-γ = H· _ _ _ _ (IH1 γ1 γ2 A-γ) (IH2 γ1 γ2 A-γ)
