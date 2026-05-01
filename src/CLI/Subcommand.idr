||| Subcommand Routing.
|||
||| Parses subcommand structure and dispatches to action handlers.
module CLI.Subcommand

import Model.Auth
import Model.Common
import Model.Project
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
  ActTaskUpdate  : String -> Maybe String -> Maybe String -> Maybe String -> Action
  ActTaskDelete  : String -> Action
  ActTaskStatus  : String -> Bits64 -> Action
  ActTaskComment     : String -> String -> Action
  ActTaskAssignStory : String -> String -> Action
  ActEpicList        : Action
  ActEpicGet     : String -> Action
  ActEpicCreate  : String -> Maybe String -> Maybe String -> Action
  ActEpicUpdate  : String -> Maybe String -> Maybe String -> Maybe String -> Action
  ActEpicDelete  : String -> Action
  ActSprintList  : Action
  ActSprintShow  : Action
  ActSprintSet   : String -> Action
  ActIssueList   : Action
  ActIssueGet    : String -> Action
  ActIssueCreate : String -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> Action
  ActIssueUpdate : String -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> Action
  ActIssueDelete : String -> Action
  ActStoryList   : Action
  ActStoryGet    : String -> Action
  ActStoryCreate : String -> Maybe String -> Maybe String -> Action
  ActStoryUpdate : String -> Maybe String -> Maybe String -> Maybe String -> Action
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
handleProjectList = do
  env_e <- resolveApiEnv
  case env_e of
    Left err  => pure $ Left err
    Right env => callToResult "Projects" $ listProjects @{env} Nothing Nothing Nothing

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
handleProjectGet = do
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
            Right env  => callToResult "Project" $ getProjectById @{env} pid

||| Handler for ActTaskList.
public export
handleTaskList : Maybe String -> IO (Either String CmdResult)
handleTaskList maybeStatus = do
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
            Right env  => callToResult "Tasks" $ listTasks @{env} (Just (show pid.id)) Nothing Nothing Nothing

||| Handler for ActTaskCreate.
public export
handleTaskCreate : String -> IO (Either String CmdResult)
handleTaskCreate subject = do
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
            Right env  => callToResult "Task created" $ createTask @{env} (show pid.id) subject Nothing Nothing Nothing Nothing

||| Handler for ActTaskGet.
public export
handleTaskGet : String -> IO (Either String CmdResult)
handleTaskGet ident = do
  id_e <- resolveTaskId ident
  case id_e of
    Left err   => pure $ Left err
    Right tid  => do
      env_e <- resolveApiEnv
      case env_e of
        Left err   => pure $ Left err
        Right env  => callToResult "Task" $ getTask @{env} tid

||| Handler for ActTaskStatus.
public export
handleTaskStatus : String -> Bits64 -> IO (Either String CmdResult)
handleTaskStatus ident statusId = do
  id_e <- resolveTaskId ident
  case id_e of
    Left err   => pure $ Left err
    Right tid  => do
      env_e <- resolveApiEnv
      case env_e of
        Left err   => pure $ Left err
        Right env  => do
          result <- getTask @{env} tid
          case result of
            Left err    => pure $ Right $ cmdError err
            Right task  => callToResult "Status changed" $ changeTaskStatus @{env} tid statusId task.version

||| Handler for ActTaskComment.
public export
handleTaskComment : String -> String -> IO (Either String CmdResult)
handleTaskComment ident text = do
  id_e <- resolveTaskId ident
  case id_e of
    Left err   => pure $ Left err
    Right tid  => do
      env_e <- resolveApiEnv
      case env_e of
        Left err   => pure $ Left err
        Right env  => do
          result <- getTask @{env} tid
          case result of
            Left err    => pure $ Right $ cmdError err
            Right task  => do
              raw_e <- taskComment @{env} tid text task.version
              pure $ case raw_e of
                Left err  => Right $ cmdError err
                Right raw => Right $ cmdOkRaw "Comment added" raw

||| Handler for ActTaskAssignStory - assigns a task to a user story.
public export
handleTaskAssignStory : String -> String -> IO (Either String CmdResult)
handleTaskAssignStory taskIdent storyIdent = do
  taskId_e <- resolveTaskId taskIdent
  case taskId_e of
    Left err   => pure $ Left err
    Right tid  => do
      storyId_e <- resolveStoryId storyIdent
      case storyId_e of
        Left err   => pure $ Left err
        Right sid  => do
          env_e <- resolveApiEnv
          case env_e of
            Left err   => pure $ Left err
            Right env  => do
              task_e <- getTask @{env} tid
              case task_e of
                Left err    => pure $ Right $ cmdError err
                Right task  => do
                  result <- assignTaskToStory @{env} tid (Just sid) task.version
                  pure $ case result of
                    Left err   => Right $ cmdError err
                    Right t    => Right $ cmdOk "Task assigned to story" t

||| Handler for ActTaskUpdate.
public export
handleTaskUpdate : String -> Maybe String -> Maybe String -> Maybe String -> IO (Either String CmdResult)
handleTaskUpdate ident mSubject mDesc mStatus = do
  id_e <- resolveTaskId ident
  case id_e of
    Left err   => pure $ Left err
    Right tid  => do
      env_e <- resolveApiEnv
      case env_e of
        Left err   => pure $ Left err
        Right env  => do
          current_e <- getTask @{env} tid
          case current_e of
            Left err     => pure $ Right $ cmdError err
            Right current =>
              let subj := case mSubject of
                            Nothing => current.subject
                            Just s  => s
                  desc := case mDesc of
                            Nothing => current.description
                            Just d  => d
                  stat := mStatus
               in callToResult "Task updated" $ updateTask @{env} tid (Just subj) (Just desc) stat current.version

||| Handler for ActTaskDelete.
public export
handleTaskDelete : String -> IO (Either String CmdResult)
handleTaskDelete ident = do
  id_e <- resolveTaskId ident
  case id_e of
    Left err   => pure $ Left err
    Right tid  => do
      env_e <- resolveApiEnv
      case env_e of
        Left err   => pure $ Left err
        Right env  => do
          confirmed <- confirmDelete ("task " ++ ident)
          if not confirmed
            then pure $ Right $ cmdInfo "Delete cancelled"
            else do
              result <- deleteTask @{env} tid
              pure $ case result of
                Left err  => Right $ cmdError err
                Right _   => Right $ cmdOk "Task deleted" $ MkDeleteResult "task" tid.id

||| Handler for ActEpicList.
public export
handleEpicList : IO (Either String CmdResult)
handleEpicList = do
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
            Right env  => callToResult "Epics" $ listEpics @{env} (show pid.id) Nothing Nothing

||| Handler for ActEpicGet.
public export
handleEpicGet : String -> IO (Either String CmdResult)
handleEpicGet ident = do
  id_e <- resolveEpicId ident
  case id_e of
    Left err   => pure $ Left err
    Right eid  => do
      env_e <- resolveApiEnv
      case env_e of
        Left err   => pure $ Left err
        Right env  => callToResult "Epic" $ getEpic @{env} eid

||| Handler for ActEpicCreate.
public export
handleEpicCreate : String -> Maybe String -> Maybe String -> IO (Either String CmdResult)
handleEpicCreate subject mDesc mStatus = do
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
            Right env  => callToResult "Epic created" $ createEpic @{env} (show pid.id) subject mDesc mStatus

||| Handler for ActEpicUpdate.
public export
handleEpicUpdate : String -> Maybe String -> Maybe String -> Maybe String -> IO (Either String CmdResult)
handleEpicUpdate ident mSubject mDesc mStatus = do
  id_e <- resolveEpicId ident
  case id_e of
    Left err   => pure $ Left err
    Right eid  => do
      env_e <- resolveApiEnv
      case env_e of
        Left err   => pure $ Left err
        Right env  => do
          current_e <- getEpic @{env} eid
          case current_e of
            Left err     => pure $ Right $ cmdError err
            Right current =>
              case current.version of
                Nothing => pure $ Right $ cmdError "Cannot update epic: no version available"
                Just ver =>
                  let subj := case mSubject of
                                Nothing => current.subject
                                Just s  => s
                      desc := case mDesc of
                                Nothing => current.description
                                Just d  => d
                      stat := mStatus
                   in callToResult "Epic updated" $ updateEpic @{env} eid (Just subj) (Just desc) stat ver

||| Handler for ActEpicDelete.
public export
handleEpicDelete : String -> IO (Either String CmdResult)
handleEpicDelete ident = do
  id_e <- resolveEpicId ident
  case id_e of
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

||| Handler for ActSprintList.
public export
handleSprintList : IO (Either String CmdResult)
handleSprintList = do
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
            Right env  => callToResult "Sprints" $ listMilestones @{env} (show pid.id) Nothing Nothing

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
handleIssueList = do
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
            Right env  => callToResult "Issues" $ listIssues @{env} (show pid.id) Nothing Nothing

||| Handler for ActIssueGet.
public export
handleIssueGet : String -> IO (Either String CmdResult)
handleIssueGet ident = do
  id_e <- resolveIssueId ident
  case id_e of
    Left err   => pure $ Left err
    Right iid  => do
      env_e <- resolveApiEnv
      case env_e of
        Left err   => pure $ Left err
        Right env  => callToResult "Issue" $ getIssue @{env} iid

||| Handler for ActIssueCreate.
public export
handleIssueCreate : String -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> IO (Either String CmdResult)
handleIssueCreate subject mDesc mPriority mSeverity mType = do
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
            Right env  => callToResult "Issue created" $ createIssue @{env} (show pid.id) subject mDesc mPriority mSeverity mType

||| Handler for ActIssueUpdate.
public export
handleIssueUpdate : String -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> IO (Either String CmdResult)
handleIssueUpdate ident mSubject mDesc mType mStatus = do
  id_e <- resolveIssueId ident
  case id_e of
    Left err   => pure $ Left err
    Right iid  => do
      env_e <- resolveApiEnv
      case env_e of
        Left err   => pure $ Left err
        Right env  => do
          current_e <- getIssue @{env} iid
          case current_e of
            Left err     => pure $ Right $ cmdError err
            Right current =>
              let subj := case mSubject of
                            Nothing => current.subject
                            Just s  => s
                  desc := case mDesc of
                            Nothing => current.description
                            Just d  => d
                  stat := mStatus
               in callToResult "Issue updated" $ updateIssue @{env} iid (Just subj) (Just desc) mType stat current.version

||| Handler for ActIssueDelete.
public export
handleIssueDelete : String -> IO (Either String CmdResult)
handleIssueDelete ident = do
  id_e <- resolveIssueId ident
  case id_e of
    Left err   => pure $ Left err
    Right iid  => do
      env_e <- resolveApiEnv
      case env_e of
        Left err   => pure $ Left err
        Right env  => do
          confirmed <- confirmDelete ("issue " ++ ident)
          if not confirmed
            then pure $ Right $ cmdInfo "Delete cancelled"
            else do
              result <- deleteIssue @{env} iid
              pure $ case result of
                Left err  => Right $ cmdError err
                Right _   => Right $ cmdOk "Issue deleted" $ MkDeleteResult "issue" iid.id

||| Handler for ActStoryList.
public export
handleStoryList : IO (Either String CmdResult)
handleStoryList = do
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
              result <- listStories @{env} (show pid.id) Nothing Nothing
              pure $ case result of
                Left err   => Right $ cmdError err
                Right vals => Right $ cmdOk "Stories" vals

||| Handler for ActStoryGet.
public export
handleStoryGet : String -> IO (Either String CmdResult)
handleStoryGet ident = do
  id_e <- resolveStoryId ident
  case id_e of
    Left err   => pure $ Left err
    Right sid  => do
      env_e <- resolveApiEnv
      case env_e of
        Left err   => pure $ Left err
        Right env  => do
          result <- getStory @{env} sid
          pure $ case result of
            Left err   => Right $ cmdError err
            Right val  => Right $ cmdOk "Story" val

||| Handler for ActStoryCreate.
public export
handleStoryCreate : String -> Maybe String -> Maybe String -> IO (Either String CmdResult)
handleStoryCreate subject mDesc mMilestone = do
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
              mMsId <- case mMilestone of
                          Nothing => pure Nothing
                          Just ms => do
                            ms_e <- resolveMilestoneId ms
                            pure $ case ms_e of
                              Left _  => Nothing
                              Right v => Just v
              callToResult "Story created" $ createStory @{env} (show pid.id) subject mDesc mMsId

||| Handler for ActStoryUpdate.
public export
handleStoryUpdate : String -> Maybe String -> Maybe String -> Maybe String -> IO (Either String CmdResult)
handleStoryUpdate ident mSubject mDesc mMilestone = do
  id_e <- resolveStoryId ident
  case id_e of
    Left err   => pure $ Left err
    Right sid  => do
      env_e <- resolveApiEnv
      case env_e of
        Left err   => pure $ Left err
        Right env  => do
          current_e <- getStory @{env} sid
          case current_e of
            Left err     => pure $ Right $ cmdError err
            Right current =>
              let subj := case mSubject of
                            Nothing => current.subject
                            Just s  => s
                  desc := case mDesc of
                            Nothing => current.description
                            Just d  => d
                  mMs := case mMilestone of
                           Nothing => Nothing
                           Just ms => Just ms
               in callToResult "Story updated" $ updateStory @{env} sid (Just subj) (Just desc) mMs current.version

||| Handler for ActStoryDelete.
public export
handleStoryDelete : String -> IO (Either String CmdResult)
handleStoryDelete ident = do
  id_e <- resolveStoryId ident
  case id_e of
    Left err   => pure $ Left err
    Right sid  => do
      env_e <- resolveApiEnv
      case env_e of
        Left err   => pure $ Left err
        Right env  => do
          confirmed <- confirmDelete ("story " ++ ident)
          if not confirmed
            then pure $ Right $ cmdInfo "Delete cancelled"
            else do
              result <- deleteStory @{env} sid
              pure $ case result of
                Left err  => Right $ cmdError err
                Right _   => Right $ cmdOk "Story deleted" $ MkDeleteResult "story" sid.id

||| Handler for ActWikiList.
public export
handleWikiList : IO (Either String CmdResult)
handleWikiList = do
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
              result <- listWiki @{env} (show pid.id) Nothing Nothing
              pure $ case result of
                Left err   => Right $ cmdError err
                Right vals => Right $ cmdOk "Wiki pages" vals

||| Handler for ActWikiGet.
public export
handleWikiGet : String -> IO (Either String CmdResult)
handleWikiGet ident = do
  id_e <- resolveWikiId ident
  case id_e of
    Left err   => pure $ Left err
    Right wid  => do
      env_e <- resolveApiEnv
      case env_e of
        Left err   => pure $ Left err
        Right env  => do
          result <- getWiki @{env} wid
          pure $ case result of
            Left err   => Right $ cmdError err
            Right val  => Right $ cmdOk "Wiki page" val

||| Handler for ActWikiCreate.
public export
handleWikiCreate : String -> String -> IO (Either String CmdResult)
handleWikiCreate slug content = do
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
            Right env  => callToResult "Wiki page created" $ createWiki @{env} (show pid.id) slug content

||| Handler for ActWikiUpdate.
public export
handleWikiUpdate : String -> Maybe String -> Maybe String -> IO (Either String CmdResult)
handleWikiUpdate ident mContent mSlug = do
  id_e <- resolveWikiId ident
  case id_e of
    Left err   => pure $ Left err
    Right wid  => do
      env_e <- resolveApiEnv
      case env_e of
        Left err   => pure $ Left err
        Right env  => do
          current_e <- getWiki @{env} wid
          case current_e of
            Left err     => pure $ Right $ cmdError err
            Right current =>
              let content := case mContent of
                               Nothing => current.content
                               Just c  => c
                  slug    := case mSlug of
                               Nothing => current.slug.slug
                               Just s  => s
               in callToResult "Wiki page updated" $ updateWiki @{env} wid (Just content) (Just slug) current.version

||| Handler for ActWikiDelete.
public export
handleWikiDelete : String -> IO (Either String CmdResult)
handleWikiDelete ident = do
  id_e <- resolveWikiId ident
  case id_e of
    Left err   => pure $ Left err
    Right wid  => do
      env_e <- resolveApiEnv
      case env_e of
        Left err   => pure $ Left err
        Right env  => do
          confirmed <- confirmDelete ("wiki page " ++ ident)
          if not confirmed
            then pure $ Right $ cmdInfo "Delete cancelled"
            else do
              result <- deleteWiki @{env} wid
              pure $ case result of
                Left err  => Right $ cmdError err
                Right _   => Right $ cmdOk "Wiki page deleted" $ MkDeleteResult "wiki" wid.id

||| Handler for ActSprintCreate.
public export
handleSprintCreate : String -> Maybe String -> Maybe String -> IO (Either String CmdResult)
handleSprintCreate name mStart mEnd = do
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
            Right env  => callToResult "Sprint created" $ createMilestone @{env} (show pid.id) name mStart mEnd

|||| Handler for ActSprintUpdate.
public export
handleSprintUpdate : String -> Maybe String -> Maybe String -> Maybe String -> Bits64 -> IO (Either String CmdResult)
handleSprintUpdate ident mName mStart mEnd ver = do
  id_e <- resolveMilestoneId ident
  case id_e of
    Left err   => pure $ Left err
    Right sid  => do
      env_e <- resolveApiEnv
      case env_e of
        Left err   => pure $ Left err
        Right env  => do
          current_e <- getMilestone @{env} sid
          case current_e of
            Left err     => pure $ Right $ cmdError err
            Right current =>
              let name := case mName of
                            Nothing => current.name
                            Just n  => n
                  start := mStart
                  end   := mEnd
               in callToResult "Sprint updated" $ updateMilestone @{env} sid (Just name) start end (MkVersion $ cast ver)

||| Handler for ActSprintDelete.
public export
handleSprintDelete : String -> IO (Either String CmdResult)
handleSprintDelete ident = do
  id_e <- resolveMilestoneId ident
  case id_e of
    Left err   => pure $ Left err
    Right sid  => do
      env_e <- resolveApiEnv
      case env_e of
        Left err   => pure $ Left err
        Right env  => do
          confirmed <- confirmDelete ("sprint " ++ ident)
          if not confirmed
            then pure $ Right $ cmdInfo "Delete cancelled"
            else do
              result <- deleteMilestone @{env} sid
              pure $ case result of
                Left err  => Right $ cmdError err
                Right _   => Right $ cmdOk "Sprint deleted" $ MkDeleteResult "sprint" sid.id

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
handleCommentAdd entityName ident text = do
  case (resolverEntityKey entityName, apiEntityName entityName) of
    (Nothing, _)       => pure $ Left $ "Unknown entity type: " ++ entityName ++ ". Use: task, issue, story, wiki"
    (_, Nothing)       => pure $ Left $ "Unknown entity type: " ++ entityName ++ ". Use: task, issue, story, wiki"
    (Just rKey, Just entity) => do
      id_e <- resolveToIdForType rKey ident
      case id_e of
        Left err   => pure $ Left err
        Right eid  => do
          env_e <- resolveApiEnv
          case env_e of
            Left err   => pure $ Left err
            Right env  => do
              ver_e <- fetchEntityVersion env entity eid
              case ver_e of
                Left err    => pure $ Right $ cmdError err
                Right ver   => do
                  raw_e <- addComment @{env} entity eid text ver
                  pure $ case raw_e of
                    Left err  => Right $ cmdError err
                    Right raw => Right $ cmdOkRaw "Comment added" raw

||| Handler for ActCommentList.
public export
handleCommentList : String -> String -> IO (Either String CmdResult)
handleCommentList entityName ident = do
  case (resolverEntityKey entityName, apiEntityName entityName) of
    (Nothing, _)       => pure $ Left $ "Unknown entity type: " ++ entityName ++ ". Use: task, issue, story, wiki"
    (_, Nothing)       => pure $ Left $ "Unknown entity type: " ++ entityName ++ ". Use: task, issue, story, wiki"
    (Just rKey, Just entity) => do
      id_e <- resolveToIdForType rKey ident
      case id_e of
        Left err   => pure $ Left err
        Right eid  => do
          env_e <- resolveApiEnv
          case env_e of
            Left err   => pure $ Left err
            Right env  => callToResult "Comments" $ listHistory @{env} entity eid

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
executeAction (ActTaskUpdate tid subj desc stat) = handleTaskUpdate tid subj desc stat
executeAction (ActTaskDelete tid)   = handleTaskDelete tid
executeAction (ActTaskStatus tid st) = handleTaskStatus tid st
executeAction (ActTaskComment tid txt) = handleTaskComment tid txt
executeAction (ActTaskAssignStory taskId storyId) = handleTaskAssignStory taskId storyId
executeAction ActEpicList           = handleEpicList
executeAction (ActEpicGet eid)      = handleEpicGet eid
executeAction (ActEpicCreate subj d s) = handleEpicCreate subj d s
executeAction (ActEpicUpdate eid subj d s) = handleEpicUpdate eid subj d s
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
executeAction (ActIssueUpdate iid subj d t s) = handleIssueUpdate iid subj d t s
executeAction (ActIssueDelete iid)  = handleIssueDelete iid
executeAction ActStoryList          = handleStoryList
executeAction (ActStoryGet sid)     = handleStoryGet sid
executeAction (ActStoryCreate subj d m) = handleStoryCreate subj d m
executeAction (ActStoryUpdate sid subj d m) = handleStoryUpdate sid subj d m
executeAction (ActStoryDelete sid)  = handleStoryDelete sid
executeAction ActWikiList           = handleWikiList
executeAction (ActWikiGet wid)      = handleWikiGet wid
executeAction (ActWikiCreate slug content) = handleWikiCreate slug content
executeAction (ActWikiUpdate wid content slug) = handleWikiUpdate wid content slug
executeAction (ActWikiDelete wid)   = handleWikiDelete wid
executeAction (ActCommentAdd entity ident text) = handleCommentAdd entity ident text
executeAction (ActCommentList entity ident) = handleCommentList entity ident
executeAction (ActResolve ref)      = handleResolve ref
