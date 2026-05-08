module Control.AppM
import Control.Monad.Error.Either

public export
AppM : Type -> Type
AppM a =
  EitherT String IO a

public export
runAppM : AppM a -> IO (Either String a)
runAppM =
  runEitherT

public export
liftIOEither : IO (Either String a) -> AppM a
liftIOEither =
  MkEitherT

public export
liftRawIO : IO a -> AppM a
liftRawIO io =
  MkEitherT $ map Right io

public export
appFail : String -> AppM a
appFail err =
  MkEitherT $ pure $ Left err

public export
liftEither : Either String a -> AppM a
liftEither =
  MkEitherT . pure
