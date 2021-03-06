%
% (c) The University of Glasgow 2006
%

\begin{code}
{-# OPTIONS -fno-warn-tabs #-}
-- The above warning supression flag is a temporary kludge.
-- While working on this module you are encouraged to remove it and
-- detab the module (please do the detabbing in a separate patch). See
--     http://hackage.haskell.org/trac/ghc/wiki/Commentary/CodingStyle#TabsvsSpaces
-- for details

module Kind (
        -- * Main data type
        SuperKind, Kind, typeKind,

	-- Kinds
	anyKind, liftedTypeKind, unliftedTypeKind, openTypeKind,
        argTypeKind, ubxTupleKind, constraintKind,
        mkArrowKind, mkArrowKinds,
        typeNatKind, typeStringKind,

        -- Kind constructors...
        anyKindTyCon, liftedTypeKindTyCon, openTypeKindTyCon,
        unliftedTypeKindTyCon, argTypeKindTyCon, ubxTupleKindTyCon,
        constraintKindTyCon,

        -- Super Kinds
	superKind, superKindTyCon, 
        
	pprKind, pprParendKind,

        -- ** Deconstructing Kinds
        kindAppResult, synTyConResKind,
        splitKindFunTys, splitKindFunTysN, splitKindFunTy_maybe,

        -- ** Predicates on Kinds
        isLiftedTypeKind, isUnliftedTypeKind, isOpenTypeKind,
        isUbxTupleKind, isArgTypeKind, isConstraintKind,
        isConstraintOrLiftedKind, isKind, isKindVar,
        isSuperKind, isSuperKindTyCon,
        isLiftedTypeKindCon, isConstraintKindCon,
        isAnyKind, isAnyKindCon,
        okArrowArgKind, okArrowResultKind,

        isSubArgTypeKind, isSubOpenTypeKind, 
        isSubKind, isSubKindCon, 
        tcIsSubKind, tcIsSubKindCon,
        defaultKind,

        -- ** Functions on variables
        kiVarsOfKind, kiVarsOfKinds

       ) where

#include "HsVersions.h"

import {-# SOURCE #-} Type      ( typeKind, substKiWith, eqKind )

import TypeRep
import TysPrim
import TyCon
import VarSet
import PrelNames
import Outputable
\end{code}

%************************************************************************
%*									*
	Functions over Kinds		
%*									*
%************************************************************************

\begin{code}
-- | Essentially 'funResultTy' on kinds handling pi-types too
kindFunResult :: Kind -> KindOrType -> Kind
kindFunResult (FunTy _ res) _ = res
kindFunResult (ForAllTy kv res) arg = substKiWith [kv] [arg] res
kindFunResult k _ = pprPanic "kindFunResult" (ppr k)

kindAppResult :: Kind -> [Type] -> Kind
kindAppResult k []     = k
kindAppResult k (a:as) = kindAppResult (kindFunResult k a) as

-- | Essentially 'splitFunTys' on kinds
splitKindFunTys :: Kind -> ([Kind],Kind)
splitKindFunTys (FunTy a r) = case splitKindFunTys r of
                              (as, k) -> (a:as, k)
splitKindFunTys k = ([], k)

splitKindFunTy_maybe :: Kind -> Maybe (Kind,Kind)
splitKindFunTy_maybe (FunTy a r) = Just (a,r)
splitKindFunTy_maybe _           = Nothing

-- | Essentially 'splitFunTysN' on kinds
splitKindFunTysN :: Int -> Kind -> ([Kind],Kind)
splitKindFunTysN 0 k           = ([], k)
splitKindFunTysN n (FunTy a r) = case splitKindFunTysN (n-1) r of
                                   (as, k) -> (a:as, k)
splitKindFunTysN n k = pprPanic "splitKindFunTysN" (ppr n <+> ppr k)

-- | Find the result 'Kind' of a type synonym, 
-- after applying it to its 'arity' number of type variables
-- Actually this function works fine on data types too, 
-- but they'd always return '*', so we never need to ask
synTyConResKind :: TyCon -> Kind
synTyConResKind tycon = kindAppResult (tyConKind tycon) (map mkTyVarTy (tyConTyVars tycon))

-- | See "Type#kind_subtyping" for details of the distinction between these 'Kind's
isUbxTupleKind, isOpenTypeKind, isArgTypeKind, isUnliftedTypeKind,
  isConstraintKind, isAnyKind, isConstraintOrLiftedKind :: Kind -> Bool

isOpenTypeKindCon, isUbxTupleKindCon, isArgTypeKindCon,
  isUnliftedTypeKindCon, isSubArgTypeKindCon, 
  isSubOpenTypeKindCon, isConstraintKindCon,
  isLiftedTypeKindCon, isAnyKindCon :: TyCon -> Bool


isLiftedTypeKindCon   tc = tyConUnique tc == liftedTypeKindTyConKey
isAnyKindCon          tc = tyConUnique tc == anyKindTyConKey
isOpenTypeKindCon     tc = tyConUnique tc == openTypeKindTyConKey
isUbxTupleKindCon     tc = tyConUnique tc == ubxTupleKindTyConKey
isArgTypeKindCon      tc = tyConUnique tc == argTypeKindTyConKey
isUnliftedTypeKindCon tc = tyConUnique tc == unliftedTypeKindTyConKey
isConstraintKindCon   tc = tyConUnique tc == constraintKindTyConKey

isAnyKind (TyConApp tc _) = isAnyKindCon tc
isAnyKind _               = False

isOpenTypeKind (TyConApp tc _) = isOpenTypeKindCon tc
isOpenTypeKind _               = False

isUbxTupleKind (TyConApp tc _) = isUbxTupleKindCon tc
isUbxTupleKind _               = False

isArgTypeKind (TyConApp tc _) = isArgTypeKindCon tc
isArgTypeKind _               = False

isUnliftedTypeKind (TyConApp tc _) = isUnliftedTypeKindCon tc
isUnliftedTypeKind _               = False

isConstraintKind (TyConApp tc _) = isConstraintKindCon tc
isConstraintKind _               = False

isConstraintOrLiftedKind (TyConApp tc _)
  = isConstraintKindCon tc || isLiftedTypeKindCon tc
isConstraintOrLiftedKind _ = False

--------------------------------------------
--            Kinding for arrow (->)
-- Says when a kind is acceptable on lhs or rhs of an arrow
--     arg -> res

okArrowArgKindCon, okArrowResultKindCon :: TyCon -> Bool
okArrowArgKindCon kc
  | isLiftedTypeKindCon   kc = True
  | isUnliftedTypeKindCon kc = True
  | isConstraintKindCon   kc = True
  | otherwise                = False

okArrowResultKindCon kc
  | okArrowArgKindCon kc = True
  | isUbxTupleKindCon kc = True
  | otherwise            = False

okArrowArgKind, okArrowResultKind :: Kind -> Bool
okArrowArgKind    (TyConApp kc []) = okArrowArgKindCon kc
okArrowArgKind    _                = False

okArrowResultKind (TyConApp kc []) = okArrowResultKindCon kc
okArrowResultKind _                = False

-----------------------------------------
--              Subkinding
-- The tc variants are used during type-checking, where we don't want the
-- Constraint kind to be a subkind of anything
-- After type-checking (in core), Constraint is a subkind of argTypeKind
isSubOpenTypeKind :: Kind -> Bool
-- ^ True of any sub-kind of OpenTypeKind
isSubOpenTypeKind (TyConApp kc []) = isSubOpenTypeKindCon kc
isSubOpenTypeKind _                = False

isSubOpenTypeKindCon kc
  =  isSubArgTypeKindCon kc
  || isUbxTupleKindCon   kc
  || isOpenTypeKindCon   kc

isSubArgTypeKindCon kc
  =  isUnliftedTypeKindCon kc
  || isLiftedTypeKindCon   kc  
  || isArgTypeKindCon      kc     
  || isConstraintKindCon kc   -- Needed for error (Num a) "blah"
                              -- and so that (Ord a -> Eq a) is well-kinded
                              -- and so that (# Eq a, Ord b #) is well-kinded

isSubArgTypeKind :: Kind -> Bool
-- ^ True of any sub-kind of ArgTypeKind 
isSubArgTypeKind (TyConApp kc []) = isSubArgTypeKindCon kc
isSubArgTypeKind _                = False

-- | Is this a kind (i.e. a type-of-types)?
isKind :: Kind -> Bool
isKind k = isSuperKind (typeKind k)

isSubKind :: Kind -> Kind -> Bool
-- ^ @k1 \`isSubKind\` k2@ checks that @k1@ <: @k2@

isSuperKindTyCon :: TyCon -> Bool
isSuperKindTyCon tc = tc `hasKey` superKindTyConKey

isSubKind (FunTy a1 r1) (FunTy a2 r2)
  = (isSubKind a2 a1) && (isSubKind r1 r2)

isSubKind k1@(TyConApp kc1 k1s) k2@(TyConApp kc2 k2s)
  | isPromotedTypeTyCon kc1 || isPromotedTypeTyCon kc2
    -- handles promoted kinds (List *, Nat, etc.)
  = eqKind k1 k2

  | isSuperKindTyCon kc1 || isSuperKindTyCon kc2
    -- handles BOX
  = ASSERT2( isSuperKindTyCon kc2 && isSuperKindTyCon kc2 
             && null k1s && null k2s, 
             ppr kc1 <+> ppr kc2 )
    True   -- If one is BOX, the other must be too

  | otherwise = -- handles usual kinds (*, #, (#), etc.)
                ASSERT2( null k1s && null k2s, ppr k1 <+> ppr k2 )
                kc1 `isSubKindCon` kc2

isSubKind k1 k2 = eqKind k1 k2

isSubKindCon :: TyCon -> TyCon -> Bool
-- ^ @kc1 \`isSubKindCon\` kc2@ checks that @kc1@ <: @kc2@
isSubKindCon kc1 kc2
  | kc1 == kc2            = True
  | isArgTypeKindCon  kc2 = isSubArgTypeKindCon  kc1
  | isOpenTypeKindCon kc2 = isSubOpenTypeKindCon kc1 
  | otherwise             = False

-------------------------
-- Hack alert: we need a tiny variant for the typechecker
-- Reason:     f :: Int -> (a~b)
--             g :: forall (c::Constraint). Int -> c
-- We want to reject these, even though Constraint is
-- a sub-kind of OpenTypeKind.  It must be a sub-kind of OpenTypeKind
-- *after* the typechecker
--   a) So that (Ord a -> Eq a) is a legal type
--   b) So that the simplifer can generate (error (Eq a) "urk")
--
-- Easiest way to reject is simply to make Constraint not
-- below OpenTypeKind when type checking

tcIsSubKind :: Kind -> Kind -> Bool
tcIsSubKind k1 k2
  | isConstraintKind k1 = isConstraintKind k2
  | otherwise           = isSubKind k1 k2

tcIsSubKindCon :: TyCon -> TyCon -> Bool
tcIsSubKindCon kc1 kc2
  | isConstraintKindCon kc1 = isConstraintKindCon kc2
  | otherwise               = isSubKindCon kc1 kc2

-------------------------
defaultKind :: Kind -> Kind
-- ^ Used when generalising: default OpenKind and ArgKind to *.
-- See "Type#kind_subtyping" for more information on what that means

-- When we generalise, we make generic type variables whose kind is
-- simple (* or *->* etc).  So generic type variables (other than
-- built-in constants like 'error') always have simple kinds.  This is important;
-- consider
--	f x = True
-- We want f to get type
--	f :: forall (a::*). a -> Bool
-- Not 
--	f :: forall (a::ArgKind). a -> Bool
-- because that would allow a call like (f 3#) as well as (f True),
-- and the calling conventions differ.
-- This defaulting is done in TcMType.zonkTcTyVarBndr.
--
-- The test is really whether the kind is strictly above '*'
defaultKind (TyConApp kc _args)
  | isOpenTypeKindCon kc = ASSERT( null _args ) liftedTypeKind
  | isArgTypeKindCon  kc = ASSERT( null _args ) liftedTypeKind
defaultKind k = k

-- Returns the free kind variables in a kind
kiVarsOfKind :: Kind -> VarSet
kiVarsOfKind = tyVarsOfType

kiVarsOfKinds :: [Kind] -> VarSet
kiVarsOfKinds = tyVarsOfTypes
\end{code}
