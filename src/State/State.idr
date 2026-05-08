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

public export
record AppSt where
  constructor MkAppSt
  base_url : String
  active_project : Maybe Nat64Id
  project_cache : Maybe Project

%runElab derive "AppSt" [Show, Eq, ToJSON, FromJSON]

public export
defaultState : String -> AppSt
defaultState baseUrl =
  ((MkAppSt {base_url = baseUrl}) {active_project = Nothing}) {project_cache = Nothing}

public export
loadState : IO (Either String AppSt)
loadState = do
  result <- load WorkspaceStore "state"
  pure $ (case result of
            Just st => Right st
            Nothing => Left "No state found. Run 'taiga-cli init' first.")

public export
saveState : AppSt -> IO (Either String ())
saveState st = do
  save WorkspaceStore "state" st
  pure $ Right ()

public export
setActiveProject : Nat64Id -> AppM ()
setActiveProject pid =
  do
    st <- liftIOEither loadState
    liftIOEither $ saveState (setActive st pid)
  where
    setActive : AppSt -> Nat64Id -> AppSt
    setActive st pid =
      ((MkAppSt {base_url = st.base_url}) {active_project = Just pid}) {project_cache = st.project_cache}

public export
setActiveProjectCached : Project -> AppM ()
setActiveProjectCached proj =
  do
    st <- liftIOEither loadState
    liftIOEither $ saveState (setCached st proj)
  where
    setCached : AppSt -> Project -> AppSt
    setCached st proj =
      ((MkAppSt {base_url = st.base_url}) {active_project = Just proj.id}) {project_cache = Just proj}

public export
invalidateCache : AppM ()
invalidateCache =
  do
    st <- liftIOEither loadState
    liftIOEither $ saveState (noCache st)
  where
    noCache : AppSt -> AppSt
    noCache st =
      ((MkAppSt {base_url = st.base_url}) {active_project = st.active_project}) {project_cache = Nothing}

public export
getBaseUrl : AppM String
getBaseUrl = do
  st <- liftIOEither loadState
  pure st.base_url

public export
buildApiEnvWithToken : String -> String -> ApiEnv
buildApiEnvWithToken base tok =
  MkApiEnv base tok
