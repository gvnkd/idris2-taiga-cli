||| Workspace State Model (No Secrets).
|||
||| SECURITY: This module intentionally contains NO auth fields.
||| Credentials are managed separately by State.AuthStore and never
||| persisted here, ensuring they cannot leak via git commits.
module State.State

import JSON.Derive
import JSON.ToJSON
import JSON.FromJSON
import Model.Common
import Model.Project
import State.File
import Taiga.Env
import Control.AppM
import Control.Monad.Error.Either

%language ElabReflection

||| Persistent workspace state stored in ./.taiga/state.json.
|||
||| SECURITY: This record intentionally contains NO auth fields.
||| Credentials are managed separately by AuthStore and never
||| persisted here, ensuring they cannot leak via git commits.
public export
record AppSt where
  constructor MkAppSt
  base_url       : String
  active_project : Maybe Nat64Id
  project_cache  : Maybe Project

%runElab derive "AppSt" [Show, Eq, ToJSON, FromJSON]

||| Default state for `init` command.
public export
defaultState : String -> AppSt
defaultState baseUrl =
  MkAppSt { base_url       = baseUrl
          , active_project = Nothing
          , project_cache  = Nothing
          }

||| Load workspace state.  Returns Left with error message if not
||| initialized.
public export
loadState : IO (Either String AppSt)
loadState = do
  result <- load WorkspaceStore "state"
  pure $ case result of
    Just st  => Right st
    Nothing  => Left "No state found. Run 'taiga-cli init' first."

||| Save workspace state to disk (no secrets).  Returns Left on I/O
||| error.
public export
saveState : AppSt -> IO (Either String ())
saveState st = do
  save WorkspaceStore "state" st
  pure $ Right ()

||| Set the active project and persist.
public export
setActiveProject : Nat64Id -> AppM ()
setActiveProject pid = do
  st <- liftIOEither loadState
  liftIOEither $ saveState (setActive st pid)

  where
    setActive : AppSt -> Nat64Id -> AppSt
    setActive st pid = MkAppSt { base_url       = st.base_url
                               , active_project = Just pid
                               , project_cache  = st.project_cache }

||| Set the active project with cached project details and persist.
public export
setActiveProjectCached : Project -> AppM ()
setActiveProjectCached proj = do
  st <- liftIOEither loadState
  liftIOEither $ saveState (setCached st proj)

  where
    setCached : AppSt -> Project -> AppSt
    setCached st proj = MkAppSt { base_url       = st.base_url
                                , active_project = Just proj.id
                                , project_cache  = Just proj }

||| Invalidate project cache (e.g. after project-level mutation).
public export
invalidateCache : AppM ()
invalidateCache = do
  st <- liftIOEither loadState
  liftIOEither $ saveState (noCache st)

  where
    noCache : AppSt -> AppSt
    noCache st = MkAppSt { base_url       = st.base_url
                         , active_project = st.active_project
                         , project_cache  = Nothing }

||| Get current base URL from state.
public export
getBaseUrl : AppM String
getBaseUrl = do
  st <- liftIOEither loadState
  pure st.base_url

||| Build an ApiEnv from workspace state + a resolved token.
public export
buildApiEnvWithToken : String -> String -> ApiEnv
buildApiEnvWithToken base tok = MkApiEnv base tok
