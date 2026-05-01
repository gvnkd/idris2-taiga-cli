||| Lightweight monadic wrapper for IO-based Either computations.
|||
||| Used by State/ and CLI/ modules to eliminate nested case chains.
module Control.AppM

import Control.Monad.Error.Either

||| AppM wraps IO (Either String a) using EitherT from base.
public export
AppM : Type -> Type
AppM a = EitherT String IO a

public export
runAppM : AppM a -> IO (Either String a)
runAppM = runEitherT

||| Lift an IO (Either String a) into AppM.
public export
liftIOEither : IO (Either String a) -> AppM a
liftIOEither = MkEitherT

||| Lift any raw IO action into AppM.
public export
liftRawIO : IO a -> AppM a
liftRawIO io = MkEitherT $ map Right io

||| Raise an error in the monad.
public export
appFail : String -> AppM a
appFail err = MkEitherT $ pure $ Left err

||| Lift a pure Either into the monad.
public export
liftEither : Either String a -> AppM a
liftEither = MkEitherT . pure
