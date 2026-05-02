||| Subcommand Routing.
|||
||| Parses subcommand structure and dispatches to action handlers.
module CLI.Subcommand

import Control.AppM
import Model.Auth
import Model.Common
import Model.Project
import Model.Status
import Model.Task
import Model.Epic
import Model.UserStory
import Model.Issue
import Model.Milestone
import Model.WikiPage
import Model.Comment
import JSON.Derive
import JSON.ToJSON
import JSON.Parser
import CLI.Output
import State.State
import State.AuthStore
import State.Config
import State.File
import Taiga.Env
import Taiga.Project
import Taiga.Task
import Taiga.Epic
import Taiga.UserStory
import Taiga.Issue
import Taiga.Milestone
import Taiga.Wiki
import Taiga.History
import Taiga.Search
import Taiga.Status
import Data.List
import Data.Maybe
import Data.String
import System

import Control.Monad.Error.Either
%foreign "C:isatty,libc"
prim__isatty : Int -> PrimIO Int

||| Check if stdin (file descriptor 0) is a terminal.
isStdinTTY : IO Bool
isStdinTTY = do
  res <- primIO (prim__isatty 0)
  pure (res /= 0)

||| Prompt for delete confirmation when running in a TTY.
||| When piped, auto-confirms (returns True) for scripting.
public export
confirmDelete : String -> IO Bool
confirmDelete entityDesc = do
  tty <- isStdinTTY
  if not tty
    then pure True
    else do
      putStr ("Delete " ++ entityDesc ++ "? (yes/no): ")
      res <- getLine
      pure (trim res == "yes")

%language ElabReflection

||| Description of what the user wants to do.
public export
data Action : Type where
  ActInit        : Maybe String -> Action
  ActLogin       : String -> Maybe String -> Action
  ActLogout      : Action
  ActShow        : Action
  ActProjectList : Action
  ActProjectSet  : String -> Action
  ActProjectGet  : Action
  ActTaskList    : Maybe String -> Action
  ActTaskCreate  : String -> Action
  ActTaskGet     : String -> Action
  ActTaskUpdate  : String -> Maybe String -> Maybe String -> Maybe String -> Maybe Bits64 -> Action
  ActTaskDelete  : String -> Action
  ActTaskStatus  : String -> Bits64 -> Action
  ActTaskComment     : String -> String -> Action
  ActTaskAssignStory : String -> String -> Action
  ActEpicList        : Action
  ActEpicGet     : String -> Action
  ActEpicCreate  : String -> Maybe String -> Maybe String -> Action
  ActEpicUpdate  : String -> Maybe String -> Maybe String -> Maybe String -> Maybe Bits64 -> Action
  ActEpicDelete  : String -> Action
  ActSprintList  : Action
  ActSprintShow  : Action
  ActSprintSet   : String -> Action
  ActIssueList   : Action
  ActIssueGet    : String -> Action
  ActIssueCreate : String -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> Action
  ActIssueUpdate : String -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> Maybe Bits64 -> Action
  ActIssueDelete : String -> Action
  ActStoryList   : Action
  ActStoryGet    : String -> Action
  ActStoryCreate : String -> Maybe String -> Maybe String -> Action
  ActStoryUpdate : String -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> Maybe Bits64 -> Action
  ActStoryDelete : String -> Action
  ActWikiList    : Action
  ActWikiGet     : String -> Action
  ActWikiCreate  : String -> String -> Action
  ActWikiUpdate  : String -> Maybe String -> Maybe String -> Action
  ActWikiDelete  : String -> Action
  ActSprintCreate : String -> Maybe String -> Maybe String -> Action
  ActSprintUpdate : String -> Maybe String -> Maybe String -> Maybe String -> Bits64 -> Action
  ActSprintDelete : String -> Action
  ActCommentAdd  : String -> String -> String -> Action
  ActCommentList : String -> String -> Action
  ActResolve     : String -> Action
  ActTaskStatuses    : Action
  ActIssueStatuses   : Action
  ActStoryStatuses   : Action
  ActEpicStatuses    : Action

%runElab derive "Action" [Show]

||| Resolve auth and state, returning ApiEnv for use in handlers.
public export
resolveApiEnv : AppM ApiEnv
resolveApiEnv = resolveAuth

||| Get active project or fail.
getActiveProject : AppSt -> Either String Nat64Id
getActiveProject st =
  case st.active_project of
    Nothing => Left "No active project set. Run 'taiga-cli project set <slug>' first."
    Just pid => Right pid

------------------------------------------------------------------------------
-- Project Environment Helpers (AppM from Control.AppM)
------------------------------------------------------------------------------

||| Extract project-scoped environment: load state, resolve active project,
||| and authenticate. Returns (ApiEnv, Nat64Id).
public export
getProjectEnv : AppM (ApiEnv, Nat64Id)
getProjectEnv = do
  st   <- liftIOEither loadState
  pid  <- liftEither $ getActiveProject st
  env  <- resolveApiEnv
  pure (env, pid)

||| Get the slug for the active project, using cache if available.
||| Falls back to fetching the project by ID if not cached.
getProjectSlug : ApiEnv -> AppSt -> AppM String
getProjectSlug env st =
  case st.project_cache of
    Just proj => pure proj.slug.slug
    Nothing   => do
      pid <- liftEither $ getActiveProject st
      liftIOEither $ map (map (.slug.slug)) $ getProjectById @{env} pid

||| Resolve a project-scoped ref to a database ID and entity type.
||| Uses the Taiga resolver API: GET /resolver?project=<slug>&ref=<ref>
||| Returns (entityType, id) where entityType is the JSON key from the
||| resolver response (e.g. "task", "issue", "userstory").
public export
resolveRef : String -> AppM (String, Nat64Id)
resolveRef ref = do
  st   <- liftIOEither loadState
  env  <- resolveApiEnv
  slug <- getProjectSlug env st
  jsonStr <- liftIOEither $ resolve @{env} slug ref
  case decodeEither {a = ResolveResponse} jsonStr of
    Left _    => appFail $ "Invalid resolver response for ref " ++ ref
    Right res =>
      case extractEntityFromResolve res of
        Nothing   => appFail $ "Ref " ++ ref ++ " not found in project"
        Just pair => pure pair

||| Fallback: parse a string as a raw database ID.
private
fallbackToRawId : String -> AppM Nat64Id
fallbackToRawId s =
  case readNat s of
    Nothing => appFail $ "Invalid identifier: " ++ s
    Just n  => pure $ MkNat64Id n

||| Convert a user-provided identifier string to a database Nat64Id.
||| First tries to resolve as a project ref (any entity type).
||| If ref resolution fails, falls back to treating the input as a raw
||| database ID for backward compatibility with scripts.
public export
resolveToId : String -> AppM Nat64Id
resolveToId s =
  catchE (snd <$> resolveRef s) (\_ => fallbackToRawId s)

||| Resolve an identifier constrained to a specific entity type.
||| If the ref resolves to a different entity type, falls back to raw ID.
public export
resolveToIdForType : EntityKind -> String -> AppM Nat64Id
resolveToIdForType expectedKind s =
  let expectedKey = resolverKey expectedKind
   in catchE
        (do (entityType, nid) <- resolveRef s
            if entityType == expectedKey
              then pure nid
              else fallbackToRawId s)
        (\_ => fallbackToRawId s)

||| Entity-specific resolvers.
public export
resolveTaskId      : String -> AppM Nat64Id
resolveTaskId      = resolveToIdForType TaskK

public export
resolveEpicId      : String -> AppM Nat64Id
resolveEpicId      = resolveToIdForType EpicK

public export
resolveStoryId     : String -> AppM Nat64Id
resolveStoryId     = resolveToIdForType StoryK

public export
resolveIssueId     : String -> AppM Nat64Id
resolveIssueId     = resolveToIdForType IssueK

public export
resolveWikiId      : String -> AppM Nat64Id
resolveWikiId      = resolveToIdForType WikiK

public export
resolveMilestoneId : String -> AppM Nat64Id
resolveMilestoneId = resolveToIdForType MilestoneK

||| Fetch project details for status resolution.
||| Uses the cached project if available, otherwise fetches from API.
public export
getProjectForStatus :
     ApiEnv
  -> AppSt
  -> AppM Project
getProjectForStatus env st =
  case st.project_cache of
    Just proj => pure proj
    Nothing   =>
      case st.active_project of
        Nothing   => appFail "No active project set"
        Just pid  => liftIOEither $ getProjectById @{env} pid

||| Resolve a status text to a numeric ID using project metadata.
||| Falls back to numeric parsing if the text is a number.
public export
resolveStatus :
     ApiEnv
  -> AppSt
  -> String
  -> String
  -> AppM Bits64
resolveStatus env st entityType statusText = do
  proj <- getProjectForStatus env st
  liftEither $ resolveStatusText env proj entityType statusText

||| Helper: resolve optional status text to optional numeric ID.
||| Returns Nothing if no status provided.
public export
resolveOptionalStatus :
     ApiEnv
  -> AppSt
  -> String
  -> Maybe String
  -> AppM (Maybe Bits64)
resolveOptionalStatus env st entityType mStatus =
  case mStatus of
    Nothing => pure Nothing
    Just s  => map Just $ resolveStatus env st entityType s

||| Helper: run a Taiga API call and wrap result in CmdResult.
public export
callToResult :
     ToJSON a
  => (a -> String)
  -> AppM a
  -> AppM CmdResult
callToResult fmt action =
  map (\val => cmdOk (fmt val) val) action
    `catchE` \err => pure (cmdError err)

||| Generic handler for listing entities in the active project.
public export
handleEntityList :
     ToJSON a
  => String
  -> (List a -> String)
  -> (ApiEnv -> String -> IO (Either String (List a)))
  -> IO (Either String CmdResult)
handleEntityList name fmt listFn = runAppM $ do
  (env, pid) <- getProjectEnv
  val <- liftIOEither $ listFn env (show pid.id)
  pure $ cmdOk (fmt val) val

||| Generic handler for getting an entity by identifier.
public export
handleEntityGet :
     ToJSON a
  => String
  -> (a -> String)
  -> (String -> AppM Nat64Id)
  -> (ApiEnv -> Nat64Id -> IO (Either String a))
  -> String
  -> IO (Either String CmdResult)
handleEntityGet name fmt resolveId getFn ident = runAppM $ do
  eid <- resolveId ident
  env  <- resolveApiEnv
  val <- liftIOEither $ getFn env eid
  pure $ cmdOk (fmt val) val

||| Generic handler for deleting an entity by identifier.
public export
handleEntityDelete :
     String
  -> (String -> AppM Nat64Id)
  -> (ApiEnv -> Nat64Id -> IO (Either String ()))
  -> String
  -> IO (Either String CmdResult)
handleEntityDelete name resolveId deleteFn ident = runAppM $ do
  eid <- resolveId ident
  env  <- resolveApiEnv
  confirmed <- liftRawIO (confirmDelete (name ++ " " ++ ident))
  if not confirmed
    then pure $ cmdInfo "Delete cancelled"
    else do
      liftIOEither $ deleteFn env eid
      let dr := MkDeleteResult name eid.id
      pure $ cmdOk (formatDeleteResult dr) dr

------------------------------------------------------------------------------
-- Action Handlers
------------------------------------------------------------------------------

||| Handler for ActInit.
public export
handleInit : Maybe String -> IO (Either String CmdResult)

initAux : Maybe String -> AppM CmdResult
initAux maybeBaseUrl = do
  let baseUrl := case maybeBaseUrl of
                     Just u  => u
                     Nothing => "http://localhost:8000"
  liftRawIO $ ensureDir WorkspaceStore
  _ <- liftIOEither $ saveState (defaultState baseUrl)
  pure $ cmdInfo ("Initialized taiga state in ./.taiga/ (base: " ++ baseUrl ++ ")")

handleInit maybeBaseUrl = runAppM (initAux maybeBaseUrl)

||| Read password securely.  If stdin is a TTY, disables terminal echo
||| before reading and restores it after.  If piped, reads normally.
||| Always strips the trailing newline.
public export
readPassword : IO String
readPassword = do
  tty <- isStdinTTY
  if tty
    then do
      _ <- system "stty -echo 2>/dev/null"
      putStr "Password: "
      s <- getLine
      _ <- system "stty echo 2>/dev/null"
      putStrLn ""
      pure $ trim s
    else do
      s <- getLine
      pure $ trim s

||| Handler for ActLogin.
public export
handleLogin : String -> Maybe String -> IO (Either String CmdResult)

private
loginIO : String -> Maybe String -> IO (Either String CmdResult)
loginIO user mpass = do
  password <- getPassword mpass
  let creds = MkCredentials user password
  st_e <- loadState
  case st_e of
    Left err  => pure $ Left err
    Right st  => do
      result <- authenticateIO st.base_url creds
      case result of
        Left err  => pure $ Right $ cmdError ("Login failed: " ++ err)
        Right _   => pure $ Right $ cmdInfo "Authenticated successfully"

  where
    getPassword : Maybe String -> IO String
    getPassword (Just p) = do
      putStrLn ""
      putStrLn "WARNING: Passing passwords via command line arguments is insecure."
      putStrLn "         The password may be visible in shell history and process listings."
      putStrLn "         Consider using: taiga-cli login --user USER"
      putStrLn "         and typing or piping the password when prompted."
      putStrLn ""
      pure p
    getPassword Nothing = readPassword

handleLogin user mpass = runAppM $ liftIOEither $ loginIO user mpass

||| Handler for ActLogout.
public export
handleLogout : IO (Either String CmdResult)

logoutAux : AppM CmdResult
logoutAux = do
  st <- liftIOEither loadState
  liftRawIO $ removeToken st.base_url
  pure $ cmdInfo "Logged out."

handleLogout = runAppM logoutAux

||| Handler for ActShow.
public export
handleShow : IO (Either String CmdResult)

showAux : AppM CmdResult
showAux = do
  st <- liftIOEither loadState
  pure $ cmdInfo (formatShow st)

  where
    formatShow : AppSt -> String
    formatShow st =
      let projId := case st.active_project of
                       Nothing => "(none)"
                       Just p  => show p.id
       in "Base URL: " ++ st.base_url ++ "\nActive project: " ++ projId

handleShow = runAppM showAux

||| Handler for ActProjectList.
public export
handleProjectList : IO (Either String CmdResult)

projectListAux : AppM CmdResult
projectListAux = do
  env  <- resolveApiEnv
  val <- liftIOEither $ listProjects @{env} Nothing Nothing Nothing
  pure $ cmdOk (formatProjectSummaries val) val

handleProjectList = runAppM projectListAux

||| Helper: find a project by slug in the project list.
||| Returns the project ID if found.
findProjectInList : ApiEnv -> String -> IO (Maybe Nat64Id)
findProjectInList env slug = do
  list_e <- listProjects @{env} Nothing Nothing Nothing
  pure $ case list_e of
    Left _   => Nothing
    Right ps => map (.id) $ find (\p => p.slug.slug == slug) ps

||| Helper: build a detailed error message for project access denial.
projectAccessError : String -> String
projectAccessError ident = unlines
  [ "Cannot access project '" ++ ident ++ "' by slug."
  , ""
  , "The project exists in your project list, but the slug-based lookup"
  , "endpoint requires full project membership. You may have only"
  , "public/view-level access."
  , ""
  , "Try using the numeric project ID instead:"
  , "  tcli project set <number>"
  , ""
  , "To find the numeric ID, run:"
  , "  tcli project list"
  ]

||| Handler for ActProjectSet.
public export
handleProjectSet : String -> IO (Either String CmdResult)

private
projectSetById : ApiEnv -> Nat64Id -> IO (Either String CmdResult)
projectSetById env pid = do
  res <- getProjectById @{env} pid
  case res of
    Left err'  => pure $ Right $ cmdError ("Failed to get project: " ++ err')
    Right proj => do
      _ <- runAppM $ setActiveProjectCached proj
      pure $ Right $ cmdOk ("Active project set to: " ++ proj.name ++ "\n" ++ formatProject proj) proj

private
projectSetFallbackChain : String -> ApiEnv -> IO (Either String CmdResult)
projectSetFallbackChain ident env = do
  case readNat ident of
    Just pid => projectSetById env (MkNat64Id pid)
    Nothing => do
      mPid <- findProjectInList env ident
      case mPid of
        Just pid => projectSetById env pid
        Nothing  => pure $ Right $ cmdError (projectAccessError ident)

private
projectSetIO : String -> ApiEnv -> IO (Either String CmdResult)
projectSetIO ident env = do
  slugRes <- getProjectBySlug @{env} (MkSlug ident)
  case slugRes of
    Right proj => do
      _ <- runAppM $ setActiveProjectCached proj
      pure $ Right $ cmdOk ("Active project set to: " ++ proj.name ++ "\n" ++ formatProject proj) proj
    Left _ => projectSetFallbackChain ident env

projectSetAux : String -> AppM CmdResult
projectSetAux ident = do
  env  <- resolveApiEnv
  res <- liftIOEither $ projectSetIO ident env
  pure res

handleProjectSet ident = runAppM (projectSetAux ident)

||| Handler for ActProjectGet.
public export
handleProjectGet : IO (Either String CmdResult)

projectGetAux : AppM CmdResult
projectGetAux = do
  (env, pid) <- getProjectEnv
  val <- liftIOEither $ getProjectById @{env} pid
  pure $ cmdOk (formatProject val) val

handleProjectGet = runAppM projectGetAux

||| Handler for ActTaskList.
public export
handleTaskList : Maybe String -> IO (Either String CmdResult)

taskListAux : Maybe String -> AppM CmdResult
taskListAux mStatus = do
  (env, pid) <- getProjectEnv
  val <- liftIOEither $ listTasks @{env} (Just (show pid.id)) Nothing mStatus Nothing Nothing
  pure $ cmdOk (formatTaskSummaries val) val

handleTaskList maybeStatus = runAppM (taskListAux maybeStatus)

||| Handler for ActTaskCreate.
public export
handleTaskCreate : String -> IO (Either String CmdResult)

taskCreateAux : String -> AppM CmdResult
taskCreateAux subject = do
  (env, pid) <- getProjectEnv
  val <- liftIOEither $ createTask @{env} (show pid.id) subject Nothing Nothing Nothing Nothing
  pure $ cmdOk ("Task created\n" ++ formatTask val) val

handleTaskCreate subject = runAppM (taskCreateAux subject)

||| Handler for ActTaskGet.
public export
handleTaskGet : String -> IO (Either String CmdResult)

taskGetAux : String -> AppM CmdResult
taskGetAux ident = do
  tid <- resolveTaskId ident
  env  <- resolveApiEnv
  val <- liftIOEither $ getTask @{env} tid
  pure $ cmdOk (formatTask val) val

handleTaskGet ident = runAppM (taskGetAux ident)

||| Handler for ActTaskStatus.
public export
handleTaskStatus : String -> Bits64 -> IO (Either String CmdResult)

taskStatusAux : String -> Bits64 -> AppM CmdResult
taskStatusAux ident statusId = do
  tid <- resolveTaskId ident
  env  <- resolveApiEnv
  task <- liftIOEither $ getTask @{env} tid
  val <- liftIOEither $ changeTaskStatus @{env} tid statusId task.version
  pure $ cmdOk ("Status changed\n" ++ formatTask val) val

handleTaskStatus ident statusId = runAppM (taskStatusAux ident statusId)

||| Handler for ActTaskComment.
public export
handleTaskComment : String -> String -> IO (Either String CmdResult)

taskCommentAux : String -> String -> AppM CmdResult
taskCommentAux ident text = do
  tid <- resolveTaskId ident
  env  <- resolveApiEnv
  task <- liftIOEither $ getTask @{env} tid
  raw <- liftIOEither $ taskComment @{env} tid text task.version
  pure $ cmdOkRaw "Comment added" raw

handleTaskComment ident text = runAppM (taskCommentAux ident text)

||| Handler for ActTaskAssignStory - assigns a task to a user story.
public export
handleTaskAssignStory : String -> String -> IO (Either String CmdResult)

taskAssignStoryAux : String -> String -> AppM CmdResult
taskAssignStoryAux taskIdent storyIdent = do
  tid <- resolveTaskId taskIdent
  sid <- resolveStoryId storyIdent
  env  <- resolveApiEnv
  task <- liftIOEither $ getTask @{env} tid
  val <- liftIOEither $ assignTaskToStory @{env} tid (Just sid) task.version
  pure $ cmdOk ("Task assigned to story\n" ++ formatTask val) val

handleTaskAssignStory taskIdent storyIdent = runAppM (taskAssignStoryAux taskIdent storyIdent)

||| Resolve a status parameter for an entity update.
||| Prefers explicit statusId, falls back to text resolution.
private
resolveUpdateStatus :
     ApiEnv
  -> String
  -> Maybe String
  -> Maybe Bits64
  -> AppM (Maybe Bits64)
resolveUpdateStatus env entityType mStatusText mStatusId =
  case mStatusId of
    Just id => pure $ Just id
    Nothing =>
      traverse
        (\txt => do
          state <- liftIOEither loadState
          resolveStatus env state entityType txt)
        mStatusText

||| Handler for ActTaskUpdate.
public export
handleTaskUpdate : String -> Maybe String -> Maybe String -> Maybe String -> Maybe Bits64 -> IO (Either String CmdResult)

taskUpdateAux : String -> Maybe String -> Maybe String -> Maybe String -> Maybe Bits64 -> AppM CmdResult
taskUpdateAux ident mSubject mDesc mStatusText mStatusId = do
  tid <- resolveTaskId ident
  env  <- resolveApiEnv
  current <- liftIOEither $ getTask @{env} tid
  let subj = fromMaybe current.subject mSubject
      desc = fromMaybe current.description mDesc
  stat <- resolveUpdateStatus env "task" mStatusText mStatusId
  val <- liftIOEither $ updateTask @{env} tid (Just subj) (Just desc) (map show stat) current.version
  pure $ cmdOk ("Task updated\n" ++ formatTask val) val

handleTaskUpdate ident mSubject mDesc mStatusText mStatusId = runAppM (taskUpdateAux ident mSubject mDesc mStatusText mStatusId)

||| Handler for ActTaskDelete.
public export
handleTaskDelete : String -> IO (Either String CmdResult)
handleTaskDelete = handleEntityDelete "task" resolveTaskId (\e, i => deleteTask @{e} i)

||| Handler for ActEpicDelete.
public export
handleEpicDelete : String -> IO (Either String CmdResult)
handleEpicDelete = handleEntityDelete "epic" resolveEpicId (\e, i => deleteEpic @{e} i)

||| Handler for ActEpicUpdate.
public export
handleEpicUpdate : String -> Maybe String -> Maybe String -> Maybe String -> Maybe Bits64 -> IO (Either String CmdResult)

epicUpdateAux : String -> Maybe String -> Maybe String -> Maybe String -> Maybe Bits64 -> AppM CmdResult
epicUpdateAux ident mSubject mDesc mStatusText mStatusId = do
  eid <- resolveEpicId ident
  env  <- resolveApiEnv
  current <- liftIOEither $ getEpic @{env} eid
  case current.version of
    Nothing => appFail "Cannot update epic: no version available"
    Just ver => do
      let subj = fromMaybe current.subject mSubject
          desc = fromMaybe current.description mDesc
      stat <- resolveUpdateStatus env "epic" mStatusText mStatusId
      val <- liftIOEither $ updateEpic @{env} eid (Just subj) (Just desc) (map show stat) ver
      pure $ cmdOk ("Epic updated\n" ++ formatEpic val) val

handleEpicUpdate ident mSubject mDesc mStatusText mStatusId = runAppM (epicUpdateAux ident mSubject mDesc mStatusText mStatusId)

||| Handler for ActEpicList.
public export
handleEpicList : IO (Either String CmdResult)
handleEpicList = handleEntityList "Epic" formatEpicSummaries (\e, p => listEpics @{e} p Nothing Nothing)

||| Handler for ActEpicGet.
public export
handleEpicGet : String -> IO (Either String CmdResult)
handleEpicGet = handleEntityGet "Epic" formatEpic resolveEpicId (\e, i => getEpic @{e} i)

||| Handler for ActEpicCreate.
public export
handleEpicCreate : String -> Maybe String -> Maybe String -> IO (Either String CmdResult)

epicCreateAux : String -> Maybe String -> Maybe String -> AppM CmdResult
epicCreateAux subject mDesc mStatus = do
  (env, pid) <- getProjectEnv
  val <- liftIOEither $ createEpic @{env} (show pid.id) subject mDesc mStatus
  pure $ cmdOk ("Epic created\n" ++ formatEpic val) val

handleEpicCreate subject mDesc mStatus = runAppM (epicCreateAux subject mDesc mStatus)

||| Handler for ActSprintList.
public export
handleSprintList : IO (Either String CmdResult)
handleSprintList = handleEntityList "Sprint" formatMilestoneSummaries (\e, p => listMilestones @{e} p Nothing Nothing)

||| Handler for ActSprintShow.
public export
handleSprintShow : IO (Either String CmdResult)
handleSprintShow = handleSprintList

||| Handler for ActSprintSet.
public export
handleSprintSet : String -> IO (Either String CmdResult)
handleSprintSet = handleEntityGet "Sprint" formatMilestone resolveMilestoneId (\e, i => getMilestone @{e} i)

||| Handler for ActIssueList.
public export
handleIssueList : IO (Either String CmdResult)
handleIssueList = handleEntityList "Issue" formatIssueSummaries (\e, p => listIssues @{e} p Nothing Nothing)

||| Handler for ActIssueGet.
public export
handleIssueGet : String -> IO (Either String CmdResult)
handleIssueGet = handleEntityGet "Issue" formatIssue resolveIssueId (\e, i => getIssue @{e} i)

||| Handler for ActIssueCreate.
public export
handleIssueCreate : String -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> IO (Either String CmdResult)

issueCreateAux : String -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> AppM CmdResult
issueCreateAux subject mDesc mPriority mSeverity mType = do
  (env, pid) <- getProjectEnv
  val <- liftIOEither $ createIssue @{env} (show pid.id) subject mDesc mPriority mSeverity mType
  pure $ cmdOk ("Issue created\n" ++ formatIssue val) val

handleIssueCreate subject mDesc mPriority mSeverity mType = runAppM (issueCreateAux subject mDesc mPriority mSeverity mType)

||| Handler for ActIssueUpdate.
public export
handleIssueUpdate : String -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> Maybe Bits64 -> IO (Either String CmdResult)

issueUpdateAux : String -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> Maybe Bits64 -> AppM CmdResult
issueUpdateAux ident mSubject mDesc mType mStatusText mStatusId = do
  iid <- resolveIssueId ident
  env  <- resolveApiEnv
  current <- liftIOEither $ getIssue @{env} iid
  let subj = fromMaybe current.subject mSubject
      desc = fromMaybe current.description mDesc
  stat <- resolveUpdateStatus env "issue" mStatusText mStatusId
  val <- liftIOEither $ updateIssue @{env} iid (Just subj) (Just desc) mType (map show stat) current.version
  pure $ cmdOk ("Issue updated\n" ++ formatIssue val) val

handleIssueUpdate ident mSubject mDesc mType mStatusText mStatusId = runAppM (issueUpdateAux ident mSubject mDesc mType mStatusText mStatusId)

||| Handler for ActIssueDelete.
public export
handleIssueDelete : String -> IO (Either String CmdResult)
handleIssueDelete = handleEntityDelete "issue" resolveIssueId (\e, i => deleteIssue @{e} i)

||| Handler for ActStoryList.
public export
handleStoryList : IO (Either String CmdResult)
handleStoryList = handleEntityList "Story" formatStorySummaries (\e, p => listStories @{e} p Nothing Nothing)

||| Handler for ActStoryGet.
public export
handleStoryGet : String -> IO (Either String CmdResult)
handleStoryGet = handleEntityGet "Story" formatStory resolveStoryId (\e, i => getStory @{e} i)

||| Handler for ActWikiList.
public export
handleWikiList : IO (Either String CmdResult)
handleWikiList = handleEntityList "Wiki page" formatWikiPageSummaries (\e, p => listWiki @{e} p Nothing Nothing)

||| Handler for ActWikiGet.
public export
handleWikiGet : String -> IO (Either String CmdResult)
handleWikiGet = handleEntityGet "Wiki page" formatWikiPage resolveWikiId (\e, i => getWiki @{e} i)

||| Handler for ActWikiCreate.
public export
handleWikiCreate : String -> String -> IO (Either String CmdResult)

wikiCreateAux : String -> String -> AppM CmdResult
wikiCreateAux slug content = do
  (env, pid) <- getProjectEnv
  val <- liftIOEither $ createWiki @{env} (show pid.id) slug content
  pure $ cmdOk ("Wiki page created\n" ++ formatWikiPage val) val

handleWikiCreate slug content = runAppM (wikiCreateAux slug content)

||| Handler for ActStoryCreate.
public export
handleStoryCreate : String -> Maybe String -> Maybe String -> IO (Either String CmdResult)

storyCreateAux : String -> Maybe String -> Maybe String -> AppM CmdResult
storyCreateAux subject mDesc mMilestone = do
  (env, pid) <- getProjectEnv
  let mMs = map MkNat64Id $ mMilestone >>= readNat
  val <- liftIOEither $ createStory @{env} (show pid.id) subject mDesc mMs
  pure $ cmdOk ("Story created\n" ++ formatStory val) val

handleStoryCreate subject mDesc mMilestone = runAppM (storyCreateAux subject mDesc mMilestone)

||| Handler for ActStoryUpdate.
public export
handleStoryUpdate : String -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> Maybe Bits64 -> IO (Either String CmdResult)

storyUpdateAux : String -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> Maybe Bits64 -> AppM CmdResult
storyUpdateAux ident mSubject mDesc mMilestone _ _ = do
  sid <- resolveStoryId ident
  env  <- resolveApiEnv
  current <- liftIOEither $ getStory @{env} sid
  let subj = fromMaybe current.subject mSubject
      desc = fromMaybe current.description mDesc
      mMs  = fromMaybe Nothing (map Just mMilestone)
  val <- liftIOEither $ updateStory @{env} sid (Just subj) (Just desc) mMs current.version
  pure $ cmdOk ("Story updated\n" ++ formatStory val) val

handleStoryUpdate ident mSubject mDesc mMilestone mStatusText mStatusId = runAppM (storyUpdateAux ident mSubject mDesc mMilestone mStatusText mStatusId)

||| Handler for ActStoryDelete.
public export
handleStoryDelete : String -> IO (Either String CmdResult)
handleStoryDelete = handleEntityDelete "story" resolveStoryId (\e, i => deleteStory @{e} i)

||| Handler for ActWikiUpdate.
public export
handleWikiUpdate : String -> Maybe String -> Maybe String -> IO (Either String CmdResult)

wikiUpdateAux : String -> Maybe String -> Maybe String -> AppM CmdResult
wikiUpdateAux ident mContent mSlug = do
  wid <- resolveWikiId ident
  env  <- resolveApiEnv
  current <- liftIOEither $ getWiki @{env} wid
  let content := case mContent of Nothing => current.content ; Just c => c
      slug    := case mSlug     of Nothing => current.slug.slug ; Just s => s
  val <- liftIOEither $ updateWiki @{env} wid (Just content) (Just slug) current.version
  pure $ cmdOk ("Wiki page updated\n" ++ formatWikiPage val) val

handleWikiUpdate ident mContent mSlug = runAppM (wikiUpdateAux ident mContent mSlug)

||| Handler for ActWikiDelete.
public export
handleWikiDelete : String -> IO (Either String CmdResult)
handleWikiDelete = handleEntityDelete "wiki page" resolveWikiId (\e, i => deleteWiki @{e} i)

||| Handler for ActSprintCreate.
public export
handleSprintCreate : String -> Maybe String -> Maybe String -> IO (Either String CmdResult)

sprintCreateAux : String -> Maybe String -> Maybe String -> AppM CmdResult
sprintCreateAux name mStart mEnd = do
  (env, pid) <- getProjectEnv
  val <- liftIOEither $ createMilestone @{env} (show pid.id) name mStart mEnd
  pure $ cmdOk ("Sprint created\n" ++ formatMilestone val) val

handleSprintCreate name mStart mEnd = runAppM (sprintCreateAux name mStart mEnd)


||| Handler for ActSprintUpdate.
public export
handleSprintUpdate : String -> Maybe String -> Maybe String -> Maybe String -> Bits64 -> IO (Either String CmdResult)

sprintUpdateAux : String -> Maybe String -> Maybe String -> Maybe String -> Bits64 -> AppM CmdResult
sprintUpdateAux ident mName mStart mEnd ver = do
  sid <- resolveMilestoneId ident
  env  <- resolveApiEnv
  current <- liftIOEither $ getMilestone @{env} sid
  let name := case mName of Nothing => current.name ; Just n => n
      start := mStart
      end   := mEnd
  val <- liftIOEither $ updateMilestone @{env} sid (Just name) start end (MkVersion $ cast ver)
  pure $ cmdOk ("Sprint updated\n" ++ formatMilestone val) val

handleSprintUpdate ident mName mStart mEnd ver = runAppM (sprintUpdateAux ident mName mStart mEnd ver)

||| Handler for ActSprintDelete.
public export
handleSprintDelete : String -> IO (Either String CmdResult)
handleSprintDelete = handleEntityDelete "sprint" resolveMilestoneId (\e, i => deleteMilestone @{e} i)

||| Fetch an entity by kind to get its version for comment operations.
private
fetchEntityVersion :
     ApiEnv
  -> EntityKind
  -> Nat64Id
  -> IO (Either String Bits32)
fetchEntityVersion env kind eid =
  case kind of
    TaskK  => map (map (\t => t.version.version)) $ getTask @{env} eid
    IssueK => map (map (\i => i.version.version)) $ getIssue @{env} eid
    StoryK => map (map (\s => s.version.version)) $ getStory @{env} eid
    WikiK  => map (map (\w => w.version.version)) $ getWiki @{env} eid
    _      => pure $ Left "Unknown entity type for comments"

||| Handler for ActCommentAdd.
public export
handleCommentAdd : String -> String -> String -> IO (Either String CmdResult)

commentAddAux : String -> String -> String -> AppM CmdResult
commentAddAux entityName ident text = do
  case parseEntityKind entityName of
    Nothing =>
      appFail $ "Unknown entity type: " ++ entityName
        ++ ". Use: task, issue, story, wiki"
    Just kind => do
      eid <- resolveToIdForType kind ident
      env  <- resolveApiEnv
      ver <- liftIOEither $ fetchEntityVersion env kind eid
      raw <- liftIOEither
        $ addComment @{env} (apiEntityName kind) eid text ver
      pure $ cmdOkRaw "Comment added" raw

handleCommentAdd entityName ident text = runAppM (commentAddAux entityName ident text)

||| Handler for ActCommentList.
public export
handleCommentList : String -> String -> IO (Either String CmdResult)

commentListAux : String -> String -> AppM CmdResult
commentListAux entityName ident = do
  case parseEntityKind entityName of
    Nothing =>
      appFail $ "Unknown entity type: " ++ entityName
        ++ ". Use: task, issue, story, wiki"
    Just kind => do
      eid <- resolveToIdForType kind ident
      env  <- resolveApiEnv
      val <- liftIOEither
        $ listHistory @{env} (apiEntityName kind) eid
      pure $ cmdOk (formatHistoryEntries val) val

handleCommentList entityName ident = runAppM (commentListAux entityName ident)

||| Format a status list for display.
private
formatStatusList : List StatusInfo -> String
formatStatusList ss =
  unlines $ map (\s => "  " ++ show s.id ++ "  " ++ s.name ++ "  (" ++ s.slug ++ ")") ss

||| Handler for listing statuses of a given entity type.
private
handleStatusList : String -> IO (Either String CmdResult)

statusListAux : String -> AppM CmdResult
statusListAux entityType = do
  case parseEntityKind entityType of
    Nothing => pure $ cmdInfo "Unknown entity type"
    Just kind => do
      st   <- liftIOEither loadState
      pid  <- liftEither $ getActiveProject st
      env  <- resolveApiEnv
      proj <- getProjectForStatus env st
      let statuses = statusesOf proj kind
          title = case kind of
                    TaskK  => "Task statuses"
                    IssueK => "Issue statuses"
                    StoryK => "Story statuses"
                    EpicK  => "Epic statuses"
                    _      => "Statuses"
      pure $ cmdInfo (title ++ ":\n" ++ formatStatusList statuses)

handleStatusList entityType = runAppM (statusListAux entityType)

||| Try a list of named AppM actions, returning the first success.
||| If all fail, the last error is propagated.
private
firstSuccessNamed : List (String, AppM String) -> AppM (String, String)
firstSuccessNamed [] = appFail "All entity getters failed"
firstSuccessNamed ((name, m) :: rest) =
  catchE (do json <- m; pure (name, json))
         (\_ => firstSuccessNamed rest)

||| Handler for ActResolve.
public export
handleResolve : String -> IO (Either String CmdResult)
handleResolve ref = runAppM (resolveAndLookup ref)

  where
    resolveAndLookup : String -> AppM CmdResult
    resolveAndLookup ref = do
      (_, nid) <- resolveRef ref
      env  <- resolveApiEnv
      let getters =
            [ ("task",   liftIOEither $ map (map encode) $ getTask @{env} nid)
            , ("issue",  liftIOEither $ map (map encode) $ getIssue @{env} nid)
            , ("story",  liftIOEither $ map (map encode) $ getStory @{env} nid)
            , ("epic",   liftIOEither $ map (map encode) $ getEpic @{env} nid)
            , ("wiki",   liftIOEither $ map (map encode) $ getWiki @{env} nid)
            , ("sprint", liftIOEither $ map (map encode) $ getMilestone @{env} nid)
            ]
      catchE
        (do (name, json) <- firstSuccessNamed getters
            pure $ cmdOkRaw ("Resolved ref " ++ ref ++ " to " ++ name ++ " id=" ++ show nid.id) json)
         (\_ => pure $ cmdOk ("Resolved ref " ++ ref ++ " to id " ++ show nid.id) nid)

------------------------------------------------------------------------------
-- Dispatch
------------------------------------------------------------------------------

||| Dispatch an Action to its handler.
public export
executeAction : Action -> IO (Either String CmdResult)
executeAction (ActInit mbase)       = handleInit mbase
executeAction (ActLogin user mpass) = handleLogin user mpass
executeAction ActLogout             = handleLogout
executeAction ActShow               = handleShow
executeAction ActProjectList        = handleProjectList
executeAction (ActProjectSet slug)  = handleProjectSet slug
executeAction ActProjectGet         = handleProjectGet
executeAction (ActTaskList mstatus) = handleTaskList mstatus
executeAction (ActTaskCreate subj)  = handleTaskCreate subj
executeAction (ActTaskGet tid)      = handleTaskGet tid
executeAction (ActTaskUpdate tid subj desc stext sid) = handleTaskUpdate tid subj desc stext sid
executeAction (ActTaskDelete tid)   = handleTaskDelete tid
executeAction (ActTaskStatus tid st) = handleTaskStatus tid st
executeAction (ActTaskComment tid txt) = handleTaskComment tid txt
executeAction (ActTaskAssignStory taskId storyId) = handleTaskAssignStory taskId storyId
executeAction ActEpicList           = handleEpicList
executeAction (ActEpicGet eid)      = handleEpicGet eid
executeAction (ActEpicCreate subj d s) = handleEpicCreate subj d s
executeAction (ActEpicUpdate eid subj d st sid) = handleEpicUpdate eid subj d st sid
executeAction (ActEpicDelete eid)   = handleEpicDelete eid
executeAction ActSprintList         = handleSprintList
executeAction ActSprintShow         = handleSprintShow
executeAction (ActSprintSet sid)    = handleSprintSet sid
executeAction (ActSprintCreate name start end) = handleSprintCreate name start end
executeAction (ActSprintUpdate sid name start end ver) = handleSprintUpdate sid name start end ver
executeAction (ActSprintDelete sid) = handleSprintDelete sid
executeAction ActIssueList          = handleIssueList
executeAction (ActIssueGet iid)     = handleIssueGet iid
executeAction (ActIssueCreate subj d p s t) = handleIssueCreate subj d p s t
executeAction (ActIssueUpdate iid subj d t st sid) = handleIssueUpdate iid subj d t st sid
executeAction (ActIssueDelete iid)  = handleIssueDelete iid
executeAction ActStoryList          = handleStoryList
executeAction (ActStoryGet sid)     = handleStoryGet sid
executeAction (ActStoryCreate subj d m) = handleStoryCreate subj d m
executeAction (ActStoryUpdate sid subj d m st sid2) = handleStoryUpdate sid subj d m st sid2
executeAction (ActStoryDelete sid)  = handleStoryDelete sid
executeAction ActWikiList           = handleWikiList
executeAction (ActWikiGet wid)      = handleWikiGet wid
executeAction ActTaskStatuses       = handleStatusList "task"
executeAction ActIssueStatuses      = handleStatusList "issue"
executeAction ActStoryStatuses      = handleStatusList "us"
executeAction ActEpicStatuses       = handleStatusList "epic"
executeAction (ActWikiCreate slug content) = handleWikiCreate slug content
executeAction (ActWikiUpdate wid content slug) = handleWikiUpdate wid content slug
executeAction (ActWikiDelete wid)   = handleWikiDelete wid
executeAction (ActCommentAdd entity ident text) = handleCommentAdd entity ident text
executeAction (ActCommentList entity ident) = handleCommentList entity ident
executeAction (ActResolve ref)      = handleResolve ref
