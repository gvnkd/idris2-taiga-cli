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

%language ElabReflection

||| Persistent workspace state stored in ./taiga/state.json.
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
setActiveProject : Nat64Id -> IO (Either String ())
setActiveProject pid = do
  st_e <- loadState
  case st_e of
    Left err  => pure $ Left err
    Right st  => do
      let st' := { active_project := Just pid } st
      saveState st'

||| Invalidate project cache (e.g. after project-level mutation).
public export
invalidateCache : IO (Either String ())
invalidateCache = do
  st_e <- loadState
  case st_e of
    Left err  => pure $ Left err
    Right st  => do
      let st' := { project_cache := Nothing } st
      saveState st'

||| Get current base URL from state.
public export
getBaseUrl : IO (Either String String)
getBaseUrl = do
  st_e <- loadState
  pure $ case st_e of
    Left err  => Left err
    Right st  => Right st.base_url

||| Build an ApiEnv from workspace state + a resolved token.
public export
buildApiEnvWithToken : String -> String -> ApiEnv
buildApiEnvWithToken base tok = MkApiEnv base tok
