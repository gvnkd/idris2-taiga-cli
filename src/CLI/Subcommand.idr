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
  ActTaskStatus  : String -> Bits64 -> Action
  ActTaskComment : String -> String -> Action
  ActEpicList    : Action
  ActEpicGet     : String -> Action
  ActSprintList  : Action
  ActSprintShow  : Action
  ActSprintSet   : String -> Action
  ActIssueList   : Action
  ActIssueGet    : String -> Action
  ActStoryList   : Action
  ActStoryGet    : String -> Action
  ActWikiList    : Action
  ActWikiGet     : String -> Action
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

||| Resolve a project-scoped ref to a database ID.
||| Uses the Taiga resolver API: GET /resolver?project=<slug>&ref=<ref>
public export
resolveRef : String -> IO (Either String Nat64Id)
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
                  -- The resolve API returns {"project": N, "task": N} or similar.
                  -- We extract the first numeric value that isn't the project key.
                  case extractIdFromResolve jsonStr of
                    Nothing => pure $ Left $ "Ref " ++ ref ++ " not found in project"
                    Just nid => pure $ Right nid

  where
    ||| Extract the first numeric ID from a raw resolve JSON response string.
    ||| Ignores the "project" key and looks for entity keys (task, issue, etc.)
    extractIdFromResolve : String -> Maybe Nat64Id
    extractIdFromResolve s =
      let pairs := forget $ split (== ',') s
          cleanPairs := map cleanPair pairs
       in findId cleanPairs
      where
        cleanPair : String -> String
        cleanPair p = trim (pack (filter (\c => c /= '"') (unpack p)))

        findId : List String -> Maybe Nat64Id
        findId [] = Nothing
        findId (p :: ps) =
          case break (== ':') (unpack p) of
            (keyChars, ':' :: valChars) =>
              let key := trim (pack (filter (\c => c /= '{' && c /= '"') keyChars))
                  val := trim (pack (filter (\c => c /= '}' && c /= '"' && c /= ' ') valChars))
               in if key == "project"
                    then findId ps
                    else case readNat val of
                           Just n  => Just $ MkNat64Id n
                           Nothing => findId ps
            _ => findId ps

||| Convert a user-provided identifier string to a database Nat64Id.
||| First tries to resolve as a project ref (the user-facing identifier).
||| If ref resolution fails, falls back to treating the input as a raw
||| database ID for backward compatibility with scripts.
public export
resolveToId : String -> IO (Either String Nat64Id)
resolveToId s = do
  refResult <- resolveRef s
  case refResult of
    Right nid => pure $ Right nid
    Left _    =>
      case readNat s of
        Nothing => pure $ Left $ "Invalid identifier: " ++ s
        Just n  => pure $ Right $ MkNat64Id n

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
            Nothing  => pure $ Right $ cmdError ("Cannot resolve project: " ++ ident)
            Just pid => do
              result' <- getProjectById @{env} (MkNat64Id pid)
              case result' of
                Left err'  => pure $ Right $ cmdError ("Failed to get project: " ++ err')
                Right proj => do
                  _ <- setActiveProjectCached proj
                  pure $ Right $ cmdOk ("Active project set to: " ++ proj.name) proj

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
  id_e <- resolveToId ident
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
  id_e <- resolveToId ident
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
  id_e <- resolveToId ident
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
            Right task  => callToResult "Comment added" $ taskComment @{env} tid text task.version

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
  id_e <- resolveToId ident
  case id_e of
    Left err   => pure $ Left err
    Right eid  => do
      env_e <- resolveApiEnv
      case env_e of
        Left err   => pure $ Left err
        Right env  => callToResult "Epic" $ getEpic @{env} eid

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
  id_e <- resolveToId ident
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
  id_e <- resolveToId ident
  case id_e of
    Left err   => pure $ Left err
    Right iid  => do
      env_e <- resolveApiEnv
      case env_e of
        Left err   => pure $ Left err
        Right env  => callToResult "Issue" $ getIssue @{env} iid

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
  id_e <- resolveToId ident
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
  id_e <- resolveToId ident
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

||| Handler for ActResolve.
public export
handleResolve : String -> IO (Either String CmdResult)
handleResolve ref = do
  id_e <- resolveRef ref
  case id_e of
    Left err  => pure $ Left err
    Right nid => do
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
executeAction (ActTaskStatus tid st) = handleTaskStatus tid st
executeAction (ActTaskComment tid txt) = handleTaskComment tid txt
executeAction ActEpicList           = handleEpicList
executeAction (ActEpicGet eid)      = handleEpicGet eid
executeAction ActSprintList         = handleSprintList
executeAction ActSprintShow         = handleSprintShow
executeAction (ActSprintSet sid)    = handleSprintSet sid
executeAction ActIssueList          = handleIssueList
executeAction (ActIssueGet iid)     = handleIssueGet iid
executeAction ActStoryList          = handleStoryList
executeAction (ActStoryGet sid)     = handleStoryGet sid
executeAction ActWikiList           = handleWikiList
executeAction (ActWikiGet wid)      = handleWikiGet wid
executeAction (ActResolve ref)      = handleResolve ref
