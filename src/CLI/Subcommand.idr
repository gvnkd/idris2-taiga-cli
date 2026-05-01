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
  ActTaskGet     : Nat64Id -> Action
  ActTaskStatus  : Nat64Id -> Bits64 -> Action
  ActTaskComment : Nat64Id -> String -> Action
  ActEpicList    : Action
  ActEpicGet     : Nat64Id -> Action
  ActSprintList  : Action
  ActSprintShow  : Action
  ActSprintSet   : Nat64Id -> Action
  ActIssueList   : Action
  ActIssueGet    : Nat64Id -> Action
  ActStoryList   : Action
  ActStoryGet    : Nat64Id -> Action
  ActWikiList    : Action
  ActWikiGet     : Nat64Id -> Action

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
          _ <- setActiveProject proj.id
          pure $ Right $ cmdOk ("Active project set to: " ++ proj.name) proj
        Left _ =>
          case readNat ident of
            Nothing  => pure $ Right $ cmdError ("Cannot resolve project: " ++ ident)
            Just pid => do
              result' <- getProjectById @{env} (MkNat64Id pid)
              case result' of
                Left err'  => pure $ Right $ cmdError ("Failed to get project: " ++ err')
                Right proj => do
                  _ <- setActiveProject proj.id
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
handleTaskGet : Nat64Id -> IO (Either String CmdResult)
handleTaskGet tid = do
  env_e <- resolveApiEnv
  case env_e of
    Left err   => pure $ Left err
    Right env  => callToResult "Task" $ getTask @{env} tid

||| Handler for ActTaskStatus.
public export
handleTaskStatus : Nat64Id -> Bits64 -> IO (Either String CmdResult)
handleTaskStatus tid statusId = do
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
handleTaskComment : Nat64Id -> String -> IO (Either String CmdResult)
handleTaskComment tid text = do
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
handleEpicGet : Nat64Id -> IO (Either String CmdResult)
handleEpicGet eid = do
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
handleSprintSet : Nat64Id -> IO (Either String CmdResult)
handleSprintSet sid = do
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
handleIssueGet : Nat64Id -> IO (Either String CmdResult)
handleIssueGet iid = do
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
handleStoryGet : Nat64Id -> IO (Either String CmdResult)
handleStoryGet sid = do
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
handleWikiGet : Nat64Id -> IO (Either String CmdResult)
handleWikiGet wid = do
  env_e <- resolveApiEnv
  case env_e of
    Left err   => pure $ Left err
    Right env  => do
      result <- getWiki @{env} wid
      pure $ case result of
        Left err   => Right $ cmdError err
        Right val  => Right $ cmdOk "Wiki page" val

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
