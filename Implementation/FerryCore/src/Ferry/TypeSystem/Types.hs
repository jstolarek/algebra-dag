{-# LANGUAGE TypeSynonymInstances #-}
module Ferry.TypeSystem.Types where

import Control.Monad.Reader
import Control.Monad.State
import Control.Monad.Error
import Control.Applicative hiding (Const(..))

import Ferry.TypedCore.Data.Type
import Ferry.TypedCore.Data.Substitution 
import Ferry.Compiler.Error.Error
import Ferry.TypedCore.Data.Instances()

import qualified Data.Map as M

type AlgW = ErrorT FerryError (ReaderT TyEnv (State (Int, Subst)))

instance Applicative (AlgW) where
  pure  = return
  (<*>) = ap

runAlgW :: Substitutable a => TyEnv -> AlgW a -> (Either FerryError a, Subst)
runAlgW gam a = (x, s)
   where
    (x, (_, s)) = runState (runReaderT (runErrorT $ applyS a) gam) (1, (M.empty, M.empty))

getGamma :: AlgW TyEnv
getGamma = applyS ask

getSubst :: AlgW Subst
getSubst = liftM snd get

putSubst :: Subst -> AlgW ()
putSubst s = do
             (i, _) <- get
             put (i, s)

freshTyVar :: AlgW Ident 
freshTyVar = do
                (n, theta) <- get
                put (n + 1, theta)
                return (show n)

lookupVariable :: Ident -> AlgW TyScheme
lookupVariable i = do 
                liftM (M.findWithDefault err i) getGamma
            where 
                err = error $ "Variable " ++ i ++ " not bound in env." 

addToEnv :: Ident -> TyScheme -> AlgW a -> AlgW a
addToEnv x t a = do
                  _ <- getSubst
                  gam <- getGamma
                  local (\ _ -> M.insert x t gam) a

addSubstitution :: Subst -> FType -> FType -> Subst
addSubstitution (s, r) i t = let s' = M.singleton i t
                                 s'' = M.map (apply (s', M.empty)) s
                              in (s' `M.union` s'', r)

updateSubstitution :: FType -> FType -> AlgW ()
updateSubstitution v t = do
                            (i, s) <- get
                            let s' = addSubstitution s v t
                            put (i, s')

localAddSubstitution :: Substitutable a => FType -> FType -> AlgW a -> AlgW a
localAddSubstitution i t l = do
                            s <- getSubst
                            updateSubstitution i t
                            v <- applyS l
                            putSubst s
                            return v

localAddRecSubstitution :: Substitutable a => RLabel -> RLabel -> AlgW a -> AlgW a
localAddRecSubstitution i t l = do
                             s <- getSubst
                             updateRecSubstitution i t
                             v <- applyS l
                             putSubst s
                             return v

updateRecSubstitution :: RLabel -> RLabel -> AlgW ()
updateRecSubstitution v t = do
                           (i, s) <- get
                           let s' = addRecSubstitution s v t
                           put (i, s')

addRecSubstitution :: Subst -> RLabel -> RLabel -> Subst
addRecSubstitution (s, r) i t = let r' = M.singleton i t
                                    r'' = M.map (apply (M.empty, r')) r
                                 in (s, r' `M.union` r'')

applyS :: Substitutable a => AlgW a -> AlgW a
applyS v = do
             s <- getSubst
             v' <- v
             return $ apply s v'
             
applySubst :: Substitutable a => a -> AlgW a
applySubst v = applyS $ pure v