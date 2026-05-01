||| Subcommand Routing.
|||
||| Parses subcommand structure and dispatches to action handlers.
module CLI.Subcommand

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
import Data.String
import System

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

||| Attempt to parse a string as Bits64.  Returns Nothing on invalid
||| input.
private
readNat : String -> Maybe Bits64
readNat s =
  let n := cast {to = Integer} s in
  if s == "0" then Just 0
  else if n == 0 then Nothing
  else if n < 0 then Nothing
  else Just $ cast n

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
resolveApiEnv : IO (Either String ApiEnv)
resolveApiEnv = resolveAuth

||| Get active project or fail.
getActiveProject : AppSt -> Either String Nat64Id
getActiveProject st =
  case st.active_project of
    Nothing => Left "No active project set. Run 'taiga-cli project set <slug>' first."
    Just pid => Right pid

||| Get the slug for the active project, using cache if available.
||| Falls back to fetching the project by ID if not cached.
getProjectSlug : ApiEnv -> AppSt -> IO (Either String String)
getProjectSlug env st =
  case st.project_cache of
    Just proj => pure $ Right proj.slug.slug
    Nothing   =>
      case getActiveProject st of
        Left err  => pure $ Left err
        Right pid => do
          result <- getProjectById @{env} pid
          pure $ case result of
            Left err   => Left err
            Right proj => Right proj.slug.slug

||| Resolve a project-scoped ref to a database ID and entity type.
||| Uses the Taiga resolver API: GET /resolver?project=<slug>&ref=<ref>
||| Returns (entityType, id) where entityType is the JSON key from the
||| resolver response (e.g. "task", "issue", "userstory").
public export
resolveRef : String -> IO (Either String (String, Nat64Id))
resolveRef ref = do
  st_e <- loadState
  case st_e of
    Left err => pure $ Left err
    Right st => do
      env_e <- resolveApiEnv
      case env_e of
        Left err => pure $ Left err
        Right env => do
          slug_e <- getProjectSlug env st
          case slug_e of
            Left err => pure $ Left err
            Right slug => do
              result <- resolve @{env} slug ref
              case result of
                Left err => pure $ Left err
                Right jsonStr =>
                  case extractIdFromResolve jsonStr of
                    Nothing => pure $ Left $ "Ref " ++ ref ++ " not found in project"
                    Just pair => pure $ Right pair

  where
    ||| Extract entity type and numeric ID from a raw resolve JSON response.
    ||| Ignores the "project" key and returns the first other key-value pair.
    extractIdFromResolve : String -> Maybe (String, Nat64Id)
    extractIdFromResolve s =
      let pairs := forget $ split (== ',') s
          cleanPairs := map cleanPair pairs
       in findId cleanPairs
      where
        cleanPair : String -> String
        cleanPair p = trim (pack (filter (\c => c /= '"') (unpack p)))

        findId : List String -> Maybe (String, Nat64Id)
        findId [] = Nothing
        findId (p :: ps) =
          case break (== ':') (unpack p) of
            (keyChars, ':' :: valChars) =>
              let key := trim (pack (filter (\c => c /= '{' && c /= '"') keyChars))
                  val := trim (pack (filter (\c => c /= '}' && c /= '"' && c /= ' ') valChars))
               in if key == "project"
                    then findId ps
                    else case readNat val of
                           Just n  => Just (key, MkNat64Id n)
                           Nothing => findId ps
            _ => findId ps

||| Fallback: parse a string as a raw database ID.
private
fallbackToRawId : String -> IO (Either String Nat64Id)
fallbackToRawId s =
  case readNat s of
    Nothing => pure $ Left $ "Invalid identifier: " ++ s
    Just n  => pure $ Right $ MkNat64Id n

||| Convert a user-provided identifier string to a database Nat64Id.
||| First tries to resolve as a project ref (any entity type).
||| If ref resolution fails, falls back to treating the input as a raw
||| database ID for backward compatibility with scripts.
public export
resolveToId : String -> IO (Either String Nat64Id)
resolveToId s = do
  refResult <- resolveRef s
  case refResult of
    Right (_, nid) => pure $ Right nid
    Left _         => fallbackToRawId s

||| Resolve an identifier constrained to a specific entity type.
||| If the ref resolves to a different entity type, falls back to raw ID.
public export
resolveToIdForType : String -> String -> IO (Either String Nat64Id)
resolveToIdForType expectedType s = do
  refResult <- resolveRef s
  case refResult of
    Right (entityType, nid) =>
      if entityType == expectedType
        then pure $ Right nid
        else fallbackToRawId s
    Left _ => fallbackToRawId s

||| Map user-friendly entity name to the key used by the Taiga resolver API.
private
resolverEntityKey : String -> Maybe String
resolverEntityKey "task"   = Just "task"
resolverEntityKey "issue"  = Just "issue"
resolverEntityKey "story"  = Just "us"
resolverEntityKey "wiki"   = Just "wiki"
resolverEntityKey _        = Nothing

||| Entity-specific resolvers.
||| Note: the Taiga resolver API uses "us" (not "userstory") for user stories.
public export
resolveTaskId      : String -> IO (Either String Nat64Id)
resolveTaskId      = resolveToIdForType "task"

public export
resolveEpicId      : String -> IO (Either String Nat64Id)
resolveEpicId      = resolveToIdForType "epic"

public export
resolveStoryId     : String -> IO (Either String Nat64Id)
resolveStoryId     = resolveToIdForType "us"

public export
resolveIssueId     : String -> IO (Either String Nat64Id)
resolveIssueId     = resolveToIdForType "issue"

public export
resolveWikiId      : String -> IO (Either String Nat64Id)
resolveWikiId      = resolveToIdForType "wiki"

public export
resolveMilestoneId : String -> IO (Either String Nat64Id)
resolveMilestoneId = resolveToIdForType "milestone"

||| Fetch project details for status resolution.
||| Uses the cached project if available, otherwise fetches from API.
public export
getProjectForStatus :
     ApiEnv
  -> AppSt
  -> IO (Either String Project)
getProjectForStatus env st =
  case st.project_cache of
    Just proj => pure $ Right proj
    Nothing   =>
      case st.active_project of
        Nothing   => pure $ Left "No active project set"
        Just pid  => do
          result <- getProjectById @{env} pid
          case result of
            Left err   => pure $ Left err
            Right proj => pure $ Right proj

||| Resolve a status text to a numeric ID using project metadata.
||| Falls back to numeric parsing if the text is a number.
public export
resolveStatus :
     ApiEnv
  -> AppSt
  -> String
  -> String
  -> IO (Either String Bits64)
resolveStatus env st entityType statusText = do
  proj_e <- getProjectForStatus env st
  case proj_e of
    Left err => pure $ Left err
    Right proj => pure $ resolveStatusText env proj entityType statusText

||| Helper: resolve optional status text to optional numeric ID.
||| Returns Nothing if no status provided.
public export
resolveOptionalStatus :
     ApiEnv
  -> AppSt
  -> String
  -> Maybe String
  -> IO (Either String (Maybe Bits64))
resolveOptionalStatus env st entityType mStatus =
  case mStatus of
    Nothing => pure $ Right Nothing
    Just s  => do
      result <- resolveStatus env st entityType s
      case result of
        Left err => pure $ Left err
        Right id => pure $ Right $ Just id

||| Helper: run a Taiga API call and wrap result in CmdResult.
public export
callToResult :
     {auto _ : HasIO io}
  -> ToJSON a
  => String
  -> io (Either String a)
  -> io (Either String CmdResult)
callToResult msg action = do
  result <- action
  pure $ case result of
    Left err  => Right $ cmdError err
    Right val => Right $ cmdOk msg val

------------------------------------------------------------------------------
-- AppM Monad - eliminates nested Either boilerplate in handlers
------------------------------------------------------------------------------

||| Monadic wrapper around IO (Either String a) so that error propagation
||| is automatic instead of manual nested case chains.
public export
record AppM (a : Type) where
  constructor MkAppM
  run : IO (Either String a)

public export
runAppM : AppM a -> IO (Either String a)
runAppM app = app.run

public export
liftIOEither : IO (Either String a) -> AppM a
liftIOEither io = MkAppM io

||| Lift any raw IO action into AppM, returning the result directly.
public export
liftRawIO : IO a -> AppM a
liftRawIO act = MkAppM $ map Right act

public export
appFail : String -> AppM a
appFail err = MkAppM $ pure $ Left err

public export
appPure : Either String a -> AppM a
appPure either = MkAppM $ pure either

||| Functor instance for AppM.
public export
Functor AppM where
  map f (MkAppM io) = MkAppM $ map (map f) io

||| Applicative instance for AppM.
public export
Applicative AppM where
  pure val       = MkAppM $ pure $ Right val
  (MkAppM mf) <*> (MkAppM mv) = MkAppM $ do
    f <- mf
    v <- mv
    pure $ case (f, v) of
      (Right g, Right x) => Right (g x)
      _                  => Left "internal"

||| Monad instance for AppM.
public export
Monad AppM where
  (MkAppM mx) >>= f = MkAppM $ do
    ex <- mx
    case ex of
      Left err  => pure $ Left err
      Right val => run (f val)

||| Extract project-scoped environment: load state, resolve active project,
||| and authenticate. Returns (ApiEnv, Nat64Id).
public export
getProjectEnv : AppM (ApiEnv, Nat64Id)
getProjectEnv = do
  st  <- liftIOEither loadState
  case getActiveProject st of
    Left err => appFail err
    Right pid => do
      env <- liftIOEither resolveApiEnv
      pure (env, pid)

------------------------------------------------------------------------------
-- Action Handlers
------------------------------------------------------------------------------

||| Handler for ActInit.
public export
handleInit : Maybe String -> IO (Either String CmdResult)
handleInit maybeBaseUrl = do
  let baseUrl := case maybeBaseUrl of
                    Just u  => u
                    Nothing => "http://localhost:8000"
  ensureDir WorkspaceStore
  _ <- saveState (defaultState baseUrl)
  pure $ Right $ cmdInfo ("Initialized taiga state in ./.taiga/ (base: " ++ baseUrl ++ ")")

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
handleLogin user mpass = do
  password <- case mpass of
    Just p  => do
      putStrLn ""
      putStrLn "WARNING: Passing passwords via command line arguments is insecure."
      putStrLn "         The password may be visible in shell history and process listings."
      putStrLn "         Consider using: taiga-cli login --user USER"
      putStrLn "         and typing or piping the password when prompted."
      putStrLn ""
      pure p
    Nothing => readPassword
  let creds := MkCredentials user password
  st_e <- loadState
  case st_e of
    Left err  => pure $ Left err
    Right st  => do
      result <- authenticate st.base_url creds
      case result of
        Left err  => pure $ Right $ cmdError ("Login failed: " ++ err)
        Right _   => pure $ Right $ cmdInfo "Authenticated successfully"

||| Handler for ActLogout.
public export
handleLogout : IO (Either String CmdResult)
handleLogout = do
  st_e <- loadState
  case st_e of
    Left err  => pure $ Left err
    Right st  => do
      removeToken st.base_url
      pure $ Right $ cmdInfo "Logged out."

||| Handler for ActShow.
public export
handleShow : IO (Either String CmdResult)
handleShow = do
  st_e <- loadState
  case st_e of
    Left err  => pure $ Left err
    Right st  => do
      let msg := "Base URL: " ++ st.base_url ++ "\n" ++
                 "Active project: " ++ case st.active_project of
                                          Nothing => "(none)"
                                          Just p  => show p.id
      pure $ Right $ cmdInfo msg

||| Handler for ActProjectList.
public export
handleProjectList : IO (Either String CmdResult)

projectListAux : AppM CmdResult
projectListAux = do
  env <- liftIOEither resolveApiEnv
  val <- liftIOEither $ listProjects @{env} Nothing Nothing Nothing
  pure $ cmdOk "Projects" val

handleProjectList = runAppM projectListAux

||| Helper: find a project by slug in the project list.
||| Returns the project ID if found.
findProjectInList : ApiEnv -> String -> IO (Maybe Nat64Id)
findProjectInList env slug = do
  list_e <- listProjects @{env} Nothing Nothing Nothing
  pure $ case list_e of
    Left _   => Nothing
    Right ps => findId ps
  where
    findId : List ProjectSummary -> Maybe Nat64Id
    findId [] = Nothing
    findId (p :: ps) = if p.slug.slug == slug then Just p.id else findId ps

||| Helper: build a detailed error message for project access denial.
projectAccessError : String -> String
projectAccessError ident =
  "Cannot access project '" ++ ident ++ "' by slug.\n" ++
  "\n" ++
  "The project exists in your project list, but the slug-based lookup\n" ++
  "endpoint requires full project membership. You may have only\n" ++
  "public/view-level access.\n" ++
  "\n" ++
  "Try using the numeric project ID instead:\n" ++
  "  tcli project set <number>\n" ++
  "\n" ++
  "To find the numeric ID, run:\n" ++
  "  tcli project list"

||| Handler for ActProjectSet.
public export
handleProjectSet : String -> IO (Either String CmdResult)
handleProjectSet ident = do
  env_e <- resolveApiEnv
  case env_e of
    Left err  => pure $ Left err
    Right env => do
      result <- getProjectBySlug @{env} (MkSlug ident)
      case result of
        Right proj => do
          _ <- setActiveProjectCached proj
          pure $ Right $ cmdOk ("Active project set to: " ++ proj.name) proj
        Left _ =>
          case readNat ident of
            Just pid => do
              result' <- getProjectById @{env} (MkNat64Id pid)
              case result' of
                Left err'  => pure $ Right $ cmdError ("Failed to get project: " ++ err')
                Right proj => do
                  _ <- setActiveProjectCached proj
                  pure $ Right $ cmdOk ("Active project set to: " ++ proj.name) proj
            Nothing  => do
              -- Slug lookup failed and input is not numeric.
              -- Try to find the project in the list and use its ID.
              mPid <- findProjectInList env ident
              case mPid of
                Just pid => do
                  result' <- getProjectById @{env} pid
                  case result' of
                    Left err'  => pure $ Right $ cmdError ("Failed to get project: " ++ err')
                    Right proj => do
                      _ <- setActiveProjectCached proj
                      pure $ Right $ cmdOk ("Active project set to: " ++ proj.name) proj
                Nothing =>
                  pure $ Right $ cmdError (projectAccessError ident)

||| Handler for ActProjectGet.
public export
handleProjectGet : IO (Either String CmdResult)

projectGetAux : AppM CmdResult
projectGetAux = do
  (env, pid) <- getProjectEnv
  val <- liftIOEither $ getProjectById @{env} pid
  pure $ cmdOk "Project" val

handleProjectGet = runAppM projectGetAux

||| Handler for ActTaskList.
public export
handleTaskList : Maybe String -> IO (Either String CmdResult)

taskListAux : AppM CmdResult
taskListAux = do
  (env, pid) <- getProjectEnv
  val <- liftIOEither $ listTasks @{env} (Just (show pid.id)) Nothing Nothing Nothing
  pure $ cmdOk "Tasks" val

handleTaskList maybeStatus = runAppM taskListAux

||| Handler for ActTaskCreate.
public export
handleTaskCreate : String -> IO (Either String CmdResult)

taskCreateAux : String -> AppM CmdResult
taskCreateAux subject = do
  (env, pid) <- getProjectEnv
  val <- liftIOEither $ createTask @{env} (show pid.id) subject Nothing Nothing Nothing Nothing
  pure $ cmdOk "Task created" val

handleTaskCreate subject = runAppM (taskCreateAux subject)

||| Handler for ActTaskGet.
public export
handleTaskGet : String -> IO (Either String CmdResult)

taskGetAux : String -> AppM CmdResult
taskGetAux ident = do
  tid <- liftIOEither (resolveTaskId ident)
  env <- liftIOEither resolveApiEnv
  val <- liftIOEither $ getTask @{env} tid
  pure $ cmdOk "Task" val

handleTaskGet ident = runAppM (taskGetAux ident)

||| Handler for ActTaskStatus.
public export
handleTaskStatus : String -> Bits64 -> IO (Either String CmdResult)

taskStatusAux : String -> Bits64 -> AppM CmdResult
taskStatusAux ident statusId = do
  tid <- liftIOEither (resolveTaskId ident)
  env <- liftIOEither resolveApiEnv
  task <- liftIOEither $ getTask @{env} tid
  val <- liftIOEither $ changeTaskStatus @{env} tid statusId task.version
  pure $ cmdOk "Status changed" val

handleTaskStatus ident statusId = runAppM (taskStatusAux ident statusId)

||| Handler for ActTaskComment.
public export
handleTaskComment : String -> String -> IO (Either String CmdResult)

taskCommentAux : String -> String -> AppM CmdResult
taskCommentAux ident text = do
  tid <- liftIOEither (resolveTaskId ident)
  env <- liftIOEither resolveApiEnv
  task <- liftIOEither $ getTask @{env} tid
  raw <- liftIOEither $ taskComment @{env} tid text task.version
  pure $ cmdOkRaw "Comment added" raw

handleTaskComment ident text = runAppM (taskCommentAux ident text)

||| Handler for ActTaskAssignStory - assigns a task to a user story.
public export
handleTaskAssignStory : String -> String -> IO (Either String CmdResult)

taskAssignStoryAux : String -> String -> AppM CmdResult
taskAssignStoryAux taskIdent storyIdent = do
  tid <- liftIOEither (resolveTaskId taskIdent)
  sid <- liftIOEither (resolveStoryId storyIdent)
  env <- liftIOEither resolveApiEnv
  task <- liftIOEither $ getTask @{env} tid
  val <- liftIOEither $ assignTaskToStory @{env} tid (Just sid) task.version
  pure $ cmdOk "Task assigned to story" val

handleTaskAssignStory taskIdent storyIdent = runAppM (taskAssignStoryAux taskIdent storyIdent)

||| Resolve a status parameter for an entity update.
||| Prefers explicit statusId, falls back to text resolution.
private
resolveUpdateStatus :
     ApiEnv
  -> String
  -> Maybe String
  -> Maybe Bits64
  -> IO (Either String (Maybe Bits64))
resolveUpdateStatus env entityType mStatusText mStatusId =
  case mStatusId of
    Just id => pure $ Right $ Just id
    Nothing =>
      case mStatusText of
        Nothing => pure $ Right Nothing
        Just statusTxt => do
          state_e <- loadState
          case state_e of
            Left err    => pure $ Left err
            Right state => do
              res <- resolveStatus env state entityType statusTxt
              pure $ case res of
                Left err => Left err
                Right id => Right $ Just id

||| Handler for ActTaskUpdate.
public export
handleTaskUpdate : String -> Maybe String -> Maybe String -> Maybe String -> Maybe Bits64 -> IO (Either String CmdResult)

taskUpdateAux : String -> Maybe String -> Maybe String -> Maybe String -> Maybe Bits64 -> AppM CmdResult
taskUpdateAux ident mSubject mDesc mStatusText mStatusId = do
  tid <- liftIOEither (resolveTaskId ident)
  env <- liftIOEither resolveApiEnv
  current <- liftIOEither $ getTask @{env} tid
  let subj := case mSubject of Nothing => current.subject ; Just s => s
      desc := case mDesc     of Nothing => current.description ; Just d => d
  stat <- liftIOEither $ resolveUpdateStatus env "task" mStatusText mStatusId
  val <- liftIOEither $ updateTask @{env} tid (Just subj) (Just desc) (map show stat) current.version
  pure $ cmdOk "Task updated" val

handleTaskUpdate ident mSubject mDesc mStatusText mStatusId = runAppM (taskUpdateAux ident mSubject mDesc mStatusText mStatusId)

||| Handler for ActTaskDelete.
public export
handleTaskDelete : String -> IO (Either String CmdResult)

taskDeleteAux : String -> AppM CmdResult
taskDeleteAux ident = do
  tid <- liftIOEither (resolveTaskId ident)
  env <- liftIOEither resolveApiEnv
  confirmed <- liftRawIO (confirmDelete ("task " ++ ident))
  if not confirmed
    then pure $ cmdInfo "Delete cancelled"
    else do
      liftIOEither $ deleteTask @{env} tid
      pure $ cmdOk "Task deleted" $ MkDeleteResult "task" tid.id

handleTaskDelete ident = runAppM (taskDeleteAux ident)

||| Handler for ActEpicList.
public export
handleEpicList : IO (Either String CmdResult)

epicListAux : AppM CmdResult
epicListAux = do
  (env, pid) <- getProjectEnv
  val <- liftIOEither $ listEpics @{env} (show pid.id) Nothing Nothing
  pure $ cmdOk "Epics" val

handleEpicList = runAppM epicListAux

||| Handler for ActEpicGet.
public export
handleEpicGet : String -> IO (Either String CmdResult)

epicGetAux : String -> AppM CmdResult
epicGetAux ident = do
  eid <- liftIOEither (resolveEpicId ident)
  env <- liftIOEither resolveApiEnv
  val <- liftIOEither $ getEpic @{env} eid
  pure $ cmdOk "Epic" val

handleEpicGet ident = runAppM (epicGetAux ident)

||| Handler for ActEpicCreate.
public export
handleEpicCreate : String -> Maybe String -> Maybe String -> IO (Either String CmdResult)

epicCreateAux : String -> Maybe String -> Maybe String -> AppM CmdResult
epicCreateAux subject mDesc mStatus = do
  (env, pid) <- getProjectEnv
  val <- liftIOEither $ createEpic @{env} (show pid.id) subject mDesc mStatus
  pure $ cmdOk "Epic created" val

handleEpicCreate subject mDesc mStatus = runAppM (epicCreateAux subject mDesc mStatus)

||| Handler for ActEpicUpdate.
public export
handleEpicUpdate : String -> Maybe String -> Maybe String -> Maybe String -> Maybe Bits64 -> IO (Either String CmdResult)

epicUpdateAux : String -> Maybe String -> Maybe String -> Maybe String -> Maybe Bits64 -> AppM CmdResult
epicUpdateAux ident mSubject mDesc mStatusText mStatusId = do
  eid <- liftIOEither (resolveEpicId ident)
  env <- liftIOEither resolveApiEnv
  current <- liftIOEither $ getEpic @{env} eid
  case current.version of
    Nothing => appFail "Cannot update epic: no version available"
    Just ver => do
      let subj := case mSubject of Nothing => current.subject ; Just s => s
          desc := case mDesc     of Nothing => current.description ; Just d => d
      stat <- liftIOEither $ resolveUpdateStatus env "epic" mStatusText mStatusId
      val <- liftIOEither $ updateEpic @{env} eid (Just subj) (Just desc) (map show stat) ver
      pure $ cmdOk "Epic updated" val

handleEpicUpdate ident mSubject mDesc mStatusText mStatusId = runAppM (epicUpdateAux ident mSubject mDesc mStatusText mStatusId)

||| Handler for ActEpicDelete.
public export
handleEpicDelete : String -> IO (Either String CmdResult)

epicDeleteAux : String -> IO (Either String CmdResult)
epicDeleteAux ident = do
  eid_e <- resolveEpicId ident
  case eid_e of
    Left err   => pure $ Left err
    Right eid  => do
      env_e <- resolveApiEnv
      case env_e of
        Left err   => pure $ Left err
        Right env  => do
          confirmed <- confirmDelete ("epic " ++ ident)
          if not confirmed
            then pure $ Right $ cmdInfo "Delete cancelled"
            else do
              result <- deleteEpic @{env} eid
              pure $ case result of
                Left err  => Right $ cmdError err
                Right _   => Right $ cmdOk "Epic deleted" $ MkDeleteResult "epic" eid.id

handleEpicDelete ident = epicDeleteAux ident

||| Handler for ActSprintList.
public export
handleSprintList : IO (Either String CmdResult)

sprintListAux : AppM CmdResult
sprintListAux = do
  (env, pid) <- getProjectEnv
  val <- liftIOEither $ listMilestones @{env} (show pid.id) Nothing Nothing
  pure $ cmdOk "Sprints" val

handleSprintList = runAppM sprintListAux

||| Handler for ActSprintShow.
public export
handleSprintShow : IO (Either String CmdResult)
handleSprintShow = handleSprintList

||| Handler for ActSprintSet.
public export
handleSprintSet : String -> IO (Either String CmdResult)
handleSprintSet ident = do
  id_e <- resolveMilestoneId ident
  case id_e of
    Left err   => pure $ Left err
    Right sid  => do
      env_e <- resolveApiEnv
      case env_e of
        Left err   => pure $ Left err
        Right env  => callToResult "Sprint" $ getMilestone @{env} sid

||| Handler for ActIssueList.
public export
handleIssueList : IO (Either String CmdResult)

issueListAux : AppM CmdResult
issueListAux = do
  (env, pid) <- getProjectEnv
  val <- liftIOEither $ listIssues @{env} (show pid.id) Nothing Nothing
  pure $ cmdOk "Issues" val

handleIssueList = runAppM issueListAux

||| Handler for ActIssueGet.
public export
handleIssueGet : String -> IO (Either String CmdResult)

issueGetAux : String -> AppM CmdResult
issueGetAux ident = do
  iid <- liftIOEither (resolveIssueId ident)
  env <- liftIOEither resolveApiEnv
  val <- liftIOEither $ getIssue @{env} iid
  pure $ cmdOk "Issue" val

handleIssueGet ident = runAppM (issueGetAux ident)

||| Handler for ActIssueCreate.
public export
handleIssueCreate : String -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> IO (Either String CmdResult)

issueCreateAux : String -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> AppM CmdResult
issueCreateAux subject mDesc mPriority mSeverity mType = do
  (env, pid) <- getProjectEnv
  val <- liftIOEither $ createIssue @{env} (show pid.id) subject mDesc mPriority mSeverity mType
  pure $ cmdOk "Issue created" val

handleIssueCreate subject mDesc mPriority mSeverity mType = runAppM (issueCreateAux subject mDesc mPriority mSeverity mType)

||| Handler for ActIssueUpdate.
public export
handleIssueUpdate : String -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> Maybe Bits64 -> IO (Either String CmdResult)

issueUpdateAux : String -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> Maybe Bits64 -> AppM CmdResult
issueUpdateAux ident mSubject mDesc mType mStatusText mStatusId = do
  iid <- liftIOEither (resolveIssueId ident)
  env <- liftIOEither resolveApiEnv
  current <- liftIOEither $ getIssue @{env} iid
  let subj := case mSubject of Nothing => current.subject ; Just s => s
      desc := case mDesc     of Nothing => current.description ; Just d => d
  stat <- liftIOEither $ resolveUpdateStatus env "issue" mStatusText mStatusId
  val <- liftIOEither $ updateIssue @{env} iid (Just subj) (Just desc) mType (map show stat) current.version
  pure $ cmdOk "Issue updated" val

handleIssueUpdate ident mSubject mDesc mType mStatusText mStatusId = runAppM (issueUpdateAux ident mSubject mDesc mType mStatusText mStatusId)

||| Handler for ActIssueDelete.
public export
handleIssueDelete : String -> IO (Either String CmdResult)

issueDeleteAux : String -> AppM CmdResult
issueDeleteAux ident = do
  iid <- liftIOEither (resolveIssueId ident)
  env <- liftIOEither resolveApiEnv
  confirmed <- liftRawIO (confirmDelete ("issue " ++ ident))
  if not confirmed
    then pure $ cmdInfo "Delete cancelled"
    else do
      liftIOEither $ deleteIssue @{env} iid
      pure $ cmdOk "Issue deleted" $ MkDeleteResult "issue" iid.id

handleIssueDelete ident = runAppM (issueDeleteAux ident)

||| Handler for ActStoryList.
public export
handleStoryList : IO (Either String CmdResult)

storyListAux : AppM CmdResult
storyListAux = do
  (env, pid) <- getProjectEnv
  val <- liftIOEither $ listStories @{env} (show pid.id) Nothing Nothing
  pure $ cmdOk "Stories" val

handleStoryList = runAppM storyListAux

||| Handler for ActStoryGet.
public export
handleStoryGet : String -> IO (Either String CmdResult)

storyGetAux : String -> AppM CmdResult
storyGetAux ident = do
  sid <- liftIOEither (resolveStoryId ident)
  env <- liftIOEither resolveApiEnv
  val <- liftIOEither $ getStory @{env} sid
  pure $ cmdOk "Story" val

handleStoryGet ident = runAppM (storyGetAux ident)

||| Handler for ActWikiList.
public export
handleWikiList : IO (Either String CmdResult)

wikiListAux : AppM CmdResult
wikiListAux = do
  (env, pid) <- getProjectEnv
  val <- liftIOEither $ listWiki @{env} (show pid.id) Nothing Nothing
  pure $ cmdOk "Wiki pages" val

handleWikiList = runAppM wikiListAux

||| Handler for ActWikiGet.
public export
handleWikiGet : String -> IO (Either String CmdResult)

wikiGetAux : String -> AppM CmdResult
wikiGetAux ident = do
  wid <- liftIOEither (resolveWikiId ident)
  env <- liftIOEither resolveApiEnv
  val <- liftIOEither $ getWiki @{env} wid
  pure $ cmdOk "Wiki page" val

handleWikiGet ident = runAppM (wikiGetAux ident)

||| Handler for ActWikiCreate.
public export
handleWikiCreate : String -> String -> IO (Either String CmdResult)

wikiCreateAux : String -> String -> AppM CmdResult
wikiCreateAux slug content = do
  (env, pid) <- getProjectEnv
  val <- liftIOEither $ createWiki @{env} (show pid.id) slug content
  pure $ cmdOk "Wiki page created" val

handleWikiCreate slug content = runAppM (wikiCreateAux slug content)

||| Handler for ActStoryCreate.
public export
handleStoryCreate : String -> Maybe String -> Maybe String -> IO (Either String CmdResult)

storyCreateAux : String -> Maybe String -> Maybe String -> AppM CmdResult
storyCreateAux subject mDesc mMilestone = do
  (env, pid) <- getProjectEnv
  val <- liftIOEither $ createStory @{env} (show pid.id) subject mDesc Nothing
  pure $ cmdOk "Story created" val

handleStoryCreate subject mDesc mMilestone = runAppM (storyCreateAux subject mDesc mMilestone)

||| Handler for ActStoryUpdate.
public export
handleStoryUpdate : String -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> Maybe Bits64 -> IO (Either String CmdResult)

storyUpdateAux : String -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> Maybe Bits64 -> AppM CmdResult
storyUpdateAux ident mSubject mDesc mMilestone _ _ = do
  sid <- liftIOEither (resolveStoryId ident)
  env <- liftIOEither resolveApiEnv
  current <- liftIOEither $ getStory @{env} sid
  let subj := case mSubject of Nothing => current.subject ; Just s => s
      desc := case mDesc     of Nothing => current.description ; Just d => d
      mMs  := case mMilestone of Nothing => Nothing ; Just ms => Just ms
  val <- liftIOEither $ updateStory @{env} sid (Just subj) (Just desc) mMs current.version
  pure $ cmdOk "Story updated" val

handleStoryUpdate ident mSubject mDesc mMilestone mStatusText mStatusId = runAppM (storyUpdateAux ident mSubject mDesc mMilestone mStatusText mStatusId)

||| Handler for ActStoryDelete.
public export
handleStoryDelete : String -> IO (Either String CmdResult)

storyDeleteAux : String -> AppM CmdResult
storyDeleteAux ident = do
  sid <- liftIOEither (resolveStoryId ident)
  env <- liftIOEither resolveApiEnv
  confirmed <- liftRawIO (confirmDelete ("story " ++ ident))
  if not confirmed
    then pure $ cmdInfo "Delete cancelled"
    else do
      liftIOEither $ deleteStory @{env} sid
      pure $ cmdOk "Story deleted" $ MkDeleteResult "story" sid.id

handleStoryDelete ident = runAppM (storyDeleteAux ident)

||| Handler for ActWikiUpdate.
public export
handleWikiUpdate : String -> Maybe String -> Maybe String -> IO (Either String CmdResult)

wikiUpdateAux : String -> Maybe String -> Maybe String -> AppM CmdResult
wikiUpdateAux ident mContent mSlug = do
  wid <- liftIOEither (resolveWikiId ident)
  env <- liftIOEither resolveApiEnv
  current <- liftIOEither $ getWiki @{env} wid
  let content := case mContent of Nothing => current.content ; Just c => c
      slug    := case mSlug     of Nothing => current.slug.slug ; Just s => s
  val <- liftIOEither $ updateWiki @{env} wid (Just content) (Just slug) current.version
  pure $ cmdOk "Wiki page updated" val

handleWikiUpdate ident mContent mSlug = runAppM (wikiUpdateAux ident mContent mSlug)

||| Handler for ActWikiDelete.
public export
handleWikiDelete : String -> IO (Either String CmdResult)

wikiDeleteAux : String -> AppM CmdResult
wikiDeleteAux ident = do
  wid <- liftIOEither (resolveWikiId ident)
  env <- liftIOEither resolveApiEnv
  confirmed <- liftRawIO (confirmDelete ("wiki page " ++ ident))
  if not confirmed
    then pure $ cmdInfo "Delete cancelled"
    else do
      liftIOEither $ deleteWiki @{env} wid
      pure $ cmdOk "Wiki page deleted" $ MkDeleteResult "wiki" wid.id

handleWikiDelete ident = runAppM (wikiDeleteAux ident)

||| Handler for ActSprintCreate.
public export
handleSprintCreate : String -> Maybe String -> Maybe String -> IO (Either String CmdResult)

sprintCreateAux : String -> Maybe String -> Maybe String -> AppM CmdResult
sprintCreateAux name mStart mEnd = do
  (env, pid) <- getProjectEnv
  val <- liftIOEither $ createMilestone @{env} (show pid.id) name mStart mEnd
  pure $ cmdOk "Sprint created" val

handleSprintCreate name mStart mEnd = runAppM (sprintCreateAux name mStart mEnd)


||| Handler for ActSprintUpdate.
public export
handleSprintUpdate : String -> Maybe String -> Maybe String -> Maybe String -> Bits64 -> IO (Either String CmdResult)

sprintUpdateAux : String -> Maybe String -> Maybe String -> Maybe String -> Bits64 -> AppM CmdResult
sprintUpdateAux ident mName mStart mEnd ver = do
  sid <- liftIOEither (resolveMilestoneId ident)
  env <- liftIOEither resolveApiEnv
  current <- liftIOEither $ getMilestone @{env} sid
  let name := case mName of Nothing => current.name ; Just n => n
      start := mStart
      end   := mEnd
  val <- liftIOEither $ updateMilestone @{env} sid (Just name) start end (MkVersion $ cast ver)
  pure $ cmdOk "Sprint updated" val

handleSprintUpdate ident mName mStart mEnd ver = runAppM (sprintUpdateAux ident mName mStart mEnd ver)

||| Handler for ActSprintDelete.
public export
handleSprintDelete : String -> IO (Either String CmdResult)

sprintDeleteAux : String -> AppM CmdResult
sprintDeleteAux ident = do
  sid <- liftIOEither (resolveMilestoneId ident)
  env <- liftIOEither resolveApiEnv
  confirmed <- liftRawIO (confirmDelete ("sprint " ++ ident))
  if not confirmed
    then pure $ cmdInfo "Delete cancelled"
    else do
      liftIOEither $ deleteMilestone @{env} sid
      pure $ cmdOk "Sprint deleted" $ MkDeleteResult "sprint" sid.id

handleSprintDelete ident = runAppM (sprintDeleteAux ident)

||| Map user-friendly entity name to Taiga API entity name.
private
apiEntityName : String -> Maybe String
apiEntityName "task"   = Just "task"
apiEntityName "issue"  = Just "issue"
apiEntityName "story"  = Just "userstory"
apiEntityName "wiki"   = Just "wiki"
apiEntityName _        = Nothing

||| Fetch an entity by type to get its version for comment operations.
private
fetchEntityVersion :
     ApiEnv
  -> String
  -> Nat64Id
  -> IO (Either String Bits32)
fetchEntityVersion env entity eid =
  case entity of
    "task"   => map (map (\t => t.version.version)) $ getTask @{env} eid
    "issue"  => map (map (\i => i.version.version)) $ getIssue @{env} eid
    "userstory" => map (map (\s => s.version.version)) $ getStory @{env} eid
    "wiki"   => map (map (\w => w.version.version)) $ getWiki @{env} eid
    _        => pure $ Left $ "Unknown entity type: " ++ entity

||| Handler for ActCommentAdd.
public export
handleCommentAdd : String -> String -> String -> IO (Either String CmdResult)

commentAddAux : String -> String -> String -> AppM CmdResult
commentAddAux entityName ident text = do
  case (resolverEntityKey entityName, apiEntityName entityName) of
    (Nothing, _)       => appFail $ "Unknown entity type: " ++ entityName ++ ". Use: task, issue, story, wiki"
    (_, Nothing)       => appFail $ "Unknown entity type: " ++ entityName ++ ". Use: task, issue, story, wiki"
    (Just rKey, Just entity) => do
      eid <- liftIOEither (resolveToIdForType rKey ident)
      env <- liftIOEither resolveApiEnv
      ver <- liftIOEither $ fetchEntityVersion env entity eid
      raw <- liftIOEither $ addComment @{env} entity eid text ver
      pure $ cmdOkRaw "Comment added" raw

handleCommentAdd entityName ident text = runAppM (commentAddAux entityName ident text)

||| Handler for ActCommentList.
public export
handleCommentList : String -> String -> IO (Either String CmdResult)

commentListAux : String -> String -> AppM CmdResult
commentListAux entityName ident = do
  case (resolverEntityKey entityName, apiEntityName entityName) of
    (Nothing, _)       => appFail $ "Unknown entity type: " ++ entityName ++ ". Use: task, issue, story, wiki"
    (_, Nothing)       => appFail $ "Unknown entity type: " ++ entityName ++ ". Use: task, issue, story, wiki"
    (Just rKey, Just entity) => do
      eid <- liftIOEither (resolveToIdForType rKey ident)
      env <- liftIOEither resolveApiEnv
      val <- liftIOEither $ listHistory @{env} entity eid
      pure $ cmdOk "Comments" val

handleCommentList entityName ident = runAppM (commentListAux entityName ident)

||| Format a status list for display.
private
formatStatusList : List StatusInfo -> String
formatStatusList ss =
  unlines $ map (\s => "  " ++ show s.id ++ "  " ++ s.name ++ "  (" ++ s.slug ++ ")") ss

||| Handler for listing statuses of a given entity type.
private
handleStatusList : String -> IO (Either String CmdResult)
handleStatusList entityType = do
  st_e <- loadState
  case st_e of
    Left err  => pure $ Left err
    Right st  => do
      case getActiveProject st of
        Left err   => pure $ Left err
        Right pid  => do
          env_e <- resolveApiEnv
          case env_e of
            Left err   => pure $ Left err
            Right env  => do
              proj_e <- getProjectForStatus env st
              case proj_e of
                Left err   => pure $ Right $ cmdError err
                Right proj =>
                  let statuses := case entityType of
                                    "task"   => proj.task_statuses
                                    "issue"  => proj.issue_statuses
                                    "us"     => proj.us_statuses
                                    "epic"   => proj.epic_statuses
                                    _        => []
                      title := case entityType of
                                 "task"   => "Task statuses"
                                 "issue"  => "Issue statuses"
                                 "us"     => "Story statuses"
                                 "epic"   => "Epic statuses"
                                 _        => "Statuses"
                   in pure $ Right $ cmdInfo (title ++ ":\n" ++ formatStatusList statuses)

||| Handler for ActResolve.
public export
handleResolve : String -> IO (Either String CmdResult)
handleResolve ref = do
  id_e <- resolveRef ref
  case id_e of
    Left err  => pure $ Left err
    Right (_, nid) => do
      env_e <- resolveApiEnv
      case env_e of
        Left err  => pure $ Left err
        Right env => do
          -- Try to get the entity by its resolved ID to show full details
          -- We don't know the entity type, so we try common types
          let tryGetters : List (String, IO (Either String String))
              tryGetters =
                [ ("task",    map (map encode) $ getTask @{env} nid)
                , ("issue",   map (map encode) $ getIssue @{env} nid)
                , ("story",   map (map encode) $ getStory @{env} nid)
                , ("epic",    map (map encode) $ getEpic @{env} nid)
                , ("wiki",    map (map encode) $ getWiki @{env} nid)
                , ("sprint",  map (map encode) $ getMilestone @{env} nid)
                ]
          -- Try each getter until one succeeds
          go tryGetters ref nid
          where
            go : List (String, IO (Either String String)) -> String -> Nat64Id -> IO (Either String CmdResult)
            go [] r n          = pure $ Right $ cmdOk ("Resolved ref " ++ r ++ " to id " ++ show n.id) n
            go ((name, action) :: rest) r n = do
              result <- action
              case result of
                Right jsonStr => pure $ Right $ cmdOk ("Resolved ref " ++ r ++ " to " ++ name ++ " id=" ++ show n.id) jsonStr
                Left _        => go rest r n

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
