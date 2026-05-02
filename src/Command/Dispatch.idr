||| Command dispatch — routing parsed Commands to Taiga API calls.
module Command.Dispatch

import Command.Types
import Model.Auth
import Model.Common
import Model.Epic
import Model.Issue
import Model.Milestone
import Model.Project
import Model.Task
import Model.User
import Model.UserStory
import Model.WikiPage
import Model.Comment
import Protocol.Response
import JSON.ToJSON
import Taiga.Auth
import Taiga.Api
import Taiga.Project
import Taiga.Epic
import Taiga.UserStory
import Taiga.Task
import Taiga.Issue
import Taiga.Wiki
import Taiga.Milestone
import Taiga.Search
import Taiga.User
import Taiga.History
import Taiga.Env

||| Helper: wrap an Either result in a Response.
private wrapResult : (a -> String) -> Either String a -> Response
wrapResult encodeFn (Left err)  = Err $ MkErrorResponse False "api_error" err
wrapResult encodeFn (Right val) = Ok $ MkSuccess True (encodeFn val)

||| Helper: dispatch login (no auth needed, just base URL).
private dispatchLogin' :
     HasIO io
  => Credentials -> Maybe String -> io Response
dispatchLogin' _ Nothing =
  pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchLogin' creds (Just baseUrl) =
  map (wrapResult encode) (login baseUrl creds)

||| Helper: dispatch refresh (no auth needed, just base URL).
private dispatchRefresh' :
     HasIO io
  => String -> Maybe String -> io Response
dispatchRefresh' _ Nothing =
  pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchRefresh' refreshTok (Just baseUrl) =
  map (wrapResult encode) (refreshToken baseUrl refreshTok)

||| Helper: wrap IO action result in a Response.
private dispatchWithEnvHelper :
     HasIO io
  => io (Either String a)
   -> (a -> String)
   -> io Response
dispatchWithEnvHelper action encFn = map (wrapResult encFn) action

||| Run a paginated list action and extract just the items for JSON output.
private
runList : {0 a : Type} -> HasIO io => io (Either String (List a, PaginationMeta)) -> io (Either String (List a))
runList = map (map fst)

private dispatchWithEnv' :
     HasIO io
  => (command : Command)
   -> (env : ApiEnv)
   -> io Response
dispatchWithEnv' command env =
  case command of
        CmdMe                                              => dispatchWithEnvHelper (me env.base env.token) encode
        CmdListProjects member                             =>
          dispatchWithEnvHelper (listProjects @{env} member Nothing Nothing) encode
        CmdGetProject (Just id) _                          => dispatchWithEnvHelper (getProjectById @{env} id) encode
        CmdGetProject _ (Just slug)                        => dispatchWithEnvHelper (getProjectBySlug @{env} slug) encode
        CmdGetProject Nothing Nothing                      => pure $ Err $ MkErrorResponse False "bad_request" "Must provide id or slug"
        CmdListEpics args                               => dispatchWithEnvHelper (runList $ listEpics @{env} args.project args.page args.pageSize) encode
        CmdGetEpic (Just id)                              => dispatchWithEnvHelper (getEpic @{env} id) encode
        CmdGetEpic Nothing                                => pure $ Err $ MkErrorResponse False "bad_request" "No epic ID provided"
        CmdListStories args                             => dispatchWithEnvHelper (runList $ listStories @{env} args.project args.page args.pageSize) encode
        CmdGetStory (Just id)                             => dispatchWithEnvHelper (getStory @{env} id) encode
        CmdGetStory Nothing                               => pure $ Err $ MkErrorResponse False "bad_request" "No story ID provided"
        CmdListTasks args                              =>
          dispatchWithEnvHelper (runList $ listTasks @{env} args.project Nothing args.status args.page args.pageSize) encode
        CmdGetTask (Just id)                              => dispatchWithEnvHelper (getTask @{env} id) encode
        CmdGetTask Nothing                                => pure $ Err $ MkErrorResponse False "bad_request" "No task ID provided"
        CmdListIssues args                             => dispatchWithEnvHelper (runList $ listIssues @{env} args.project args.page args.pageSize) encode
        CmdGetIssue (Just id)                             => dispatchWithEnvHelper (getIssue @{env} id) encode
        CmdGetIssue Nothing                               => pure $ Err $ MkErrorResponse False "bad_request" "No issue ID provided"
        CmdListWiki args                               => dispatchWithEnvHelper (runList $ listWiki @{env} args.project args.page args.pageSize) encode
        CmdGetWiki (Just id)                              => dispatchWithEnvHelper (getWiki @{env} id) encode
        CmdGetWiki Nothing                                => pure $ Err $ MkErrorResponse False "bad_request" "No wiki ID provided"
        CmdListMilestones args                         => dispatchWithEnvHelper (runList $ listMilestones @{env} args.project args.page args.pageSize) encode
        CmdListUsers project                              => dispatchWithEnvHelper (listUsers @{env} project) encode
        CmdListMemberships project                        => dispatchWithEnvHelper (listMemberships @{env} project) encode
        CmdListRoles project                              => dispatchWithEnvHelper (listRoles @{env} project) encode
        CmdSearch project text                            => dispatchWithEnvHelper (search @{env} project text) id
        CmdResolve project ref                            => dispatchWithEnvHelper (resolve @{env} project ref) id
        CmdCreateEpic p s d st                            => dispatchWithEnvHelper (createEpic @{env} p s d st) encode
        CmdUpdateEpic id sj d st v                        => dispatchWithEnvHelper (updateEpic @{env} id sj d st v) encode
        CmdDeleteEpic id                                  => dispatchWithEnvHelper (deleteEpic @{env} id) (const "deleted")
        CmdCreateStory p s d m                            => dispatchWithEnvHelper (createStory @{env} p s d m) encode
        CmdUpdateStory id sj d m v                        => dispatchWithEnvHelper (updateStory @{env} id sj d m Nothing v) encode
        CmdDeleteStory id                                 => dispatchWithEnvHelper (deleteStory @{env} id) (const "deleted")
        CmdCreateTask p s st d ss ms                      =>
          dispatchWithEnvHelper (createTask @{env} p s st d ss ms) encode
        CmdUpdateTask id sj d st v                        => dispatchWithEnvHelper (updateTask @{env} id sj d st v) encode
        CmdDeleteTask id                                  => dispatchWithEnvHelper (deleteTask @{env} id) (const "deleted")
        CmdWatchTask tid                                  => dispatchWithEnvHelper (getTask @{env} tid) encode
        CmdChangeTaskStatus tid st v                      => dispatchWithEnvHelper (changeTaskStatus @{env} tid st v) encode
        CmdTaskComment tid txt v                          => dispatchWithEnvHelper (taskComment @{env} tid txt v) id
        CmdCreateIssue p s d pr sv it                     =>
          dispatchWithEnvHelper (createIssue @{env} p s d pr sv it) encode
        CmdUpdateIssue id sj d it st v                    => dispatchWithEnvHelper (updateIssue @{env} id sj d it st v) encode
        CmdDeleteIssue id                                 => dispatchWithEnvHelper (deleteIssue @{env} id) (const "deleted")
        CmdCreateWiki p sl c                              => dispatchWithEnvHelper (createWiki @{env} p sl c) encode
        CmdUpdateWiki id c sl v                           => dispatchWithEnvHelper (updateWiki @{env} id c sl v) encode
        CmdDeleteWiki id                                  => dispatchWithEnvHelper (deleteWiki @{env} id) (const "deleted")
        CmdCreateMilestone p n es ef                      =>
          dispatchWithEnvHelper (createMilestone @{env} p n es ef) encode
        CmdUpdateMilestone id n es ef v                   => dispatchWithEnvHelper (updateMilestone @{env} id n es ef v) encode
        CmdDeleteMilestone id                             => dispatchWithEnvHelper (deleteMilestone @{env} id) (const "deleted")
        CmdComment e eid t                                => dispatchWithEnvHelper (addComment @{env} e eid t 0) id
        CmdListComments e eid                             => dispatchWithEnvHelper (listHistory @{env} e eid) encode
        _                                                 => pure $ Err $ MkErrorResponse False "internal" "Unreachable"

||| Dispatch a parsed Command together with auth and base URL,
||| returning a Response.
public export
dispatchCommand :
     HasIO io =>
     (command : Command)
  -> (auth  : Maybe Model.Auth.Token)
  -> (base  : Maybe String)
  -> io Response
dispatchCommand (CmdLogin creds) _ base         = dispatchLogin' creds base
dispatchCommand (CmdRefresh rtok) _ base         = dispatchRefresh' rtok base
dispatchCommand command Nothing _                 = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchCommand _ _ Nothing                       = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchCommand command (Just token) (Just baseUrl) =
  dispatchWithEnv' command env
  where
    env : ApiEnv
    env = MkApiEnv baseUrl token.auth_token
