||| Command sum type and dispatch table.
|||
||| Each constructor corresponds to one agent-visible operation,
||| which maps to one HTTP call (or a short sequence).
module Command

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
import JSON.Derive
import JSON.ToJSON
import JSON.FromJSON
import Protocol.Request
import Protocol.Response
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


%language ElabReflection

||| Refresh token argument wrapper.
record RefreshArgs where
  constructor MkRefreshArgs
  refresh : String

%runElab derive "RefreshArgs" [Show,FromJSON]

||| Sum type of all supported commands.
public export
data Command : Type where
  -- Authentication
  CmdLogin    : Credentials -> Command
  CmdRefresh  : String       -> Command
  CmdMe       : Command

  -- Read-only / list commands
  CmdListProjects     : Maybe String -> Command
  CmdGetProject       : Maybe Nat64Id -> Maybe Slug -> Command
  CmdListEpics        : String -> Command
  CmdGetEpic          : Maybe Nat64Id -> Command
  CmdListStories      : String -> Command
  CmdGetStory         : Maybe Nat64Id -> Command
  CmdListTasks        : Maybe String -> Command
  CmdGetTask          : Maybe Nat64Id -> Command
  CmdListIssues       : String -> Command
  CmdGetIssue         : Maybe Nat64Id -> Command
  CmdListWiki         : String -> Command
  CmdGetWiki          : Maybe Nat64Id -> Command
  CmdListMilestones   : String -> Command
  CmdListUsers        : String -> Command
  CmdListMemberships  : String -> Command
  CmdListRoles        : String -> Command
  CmdSearch           : String -> String -> Command
  CmdResolve          : String -> String -> Command

  -- Write / mutation commands — epics
  CmdCreateEpic : String -> String -> Maybe String -> Maybe String -> Command
  CmdUpdateEpic : Nat64Id -> Maybe String -> Maybe String -> Maybe String -> Version -> Command
  CmdDeleteEpic : Nat64Id -> Command

  -- Write / mutation commands — stories
  CmdCreateStory : String -> String -> Maybe String -> Maybe Nat64Id -> Command
  CmdUpdateStory : Nat64Id -> Maybe String -> Maybe String -> Maybe String -> Version -> Command
  CmdDeleteStory : Nat64Id -> Command

  -- Write / mutation commands — tasks
  CmdCreateTask     : String -> String -> Maybe Nat64Id -> Maybe String -> Maybe String -> Command
  CmdUpdateTask     : Nat64Id -> Maybe String -> Maybe String -> Maybe String -> Version -> Command
  CmdDeleteTask     : Nat64Id -> Command
  CmdWatchTask      : Nat64Id -> Command
  CmdChangeTaskStatus : Nat64Id -> Bits64 -> Version -> Command
  CmdTaskComment    : Nat64Id -> String -> Version -> Command

  -- Write / mutation commands — issues
  CmdCreateIssue : String -> String -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> Command
  CmdUpdateIssue : Nat64Id -> Maybe String -> Maybe String -> Maybe String -> Version -> Command
  CmdDeleteIssue : Nat64Id -> Command

  -- Write / mutation commands — wiki
  CmdCreateWiki : String -> String -> String -> Command
  CmdUpdateWiki : Nat64Id -> Maybe String -> Maybe String -> Version -> Command
  CmdDeleteWiki : Nat64Id -> Command

  -- Comments (via history API)
  CmdComment       : String -> Nat64Id -> String -> Command
  CmdEditComment   : String -> Nat64Id -> Nat64Id -> String -> Command
  CmdDeleteComment : String -> Nat64Id -> Nat64Id -> Command
  CmdListComments  : String -> Nat64Id -> Command

  -- Milestones
  CmdCreateMilestone : String -> String -> String -> String -> Command
  CmdUpdateMilestone : Nat64Id -> Maybe String -> Maybe String -> Maybe String -> Version -> Command

%runElab derive "Command" [Show,ToJSON,FromJSON]

||| Helper: wrap an Either result in a Response.
wrapResult : (a -> String) -> Either String a -> Response
wrapResult encodeFn (Left err)  = Err $ MkErrorResponse False "api_error" err
wrapResult encodeFn (Right val) = Ok $ MkSuccess True (encodeFn val)

||| Dispatch CmdLogin: authenticate and return token.
dispatchLogin :
      HasIO io
   => (creds : Credentials)
   -> (base : Maybe String)
   -> io Response
dispatchLogin _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchLogin creds (Just baseUrl)
  = Prelude.map (wrapResult encode) (login baseUrl creds)

||| Dispatch CmdRefresh: refresh expiring token.
dispatchRefresh :
      HasIO io
   => (refreshTok : String)
   -> (base : Maybe String)
   -> io Response
dispatchRefresh _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchRefresh refreshTok (Just baseUrl)
  = Prelude.map (wrapResult encode) (refreshToken baseUrl refreshTok)

||| Dispatch CmdMe: fetch current user profile.
dispatchMe :
      HasIO io
   => (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchMe Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchMe _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchMe (Just token) (Just baseUrl)
  = Prelude.map (wrapResult encode) (me baseUrl token.auth_token)

||| Dispatch CmdWatchTask: fetch task details.
dispatchWatchTask :
      HasIO io
   => (taskId : Nat64Id)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchWatchTask _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchWatchTask _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchWatchTask taskId (Just token) (Just baseUrl)
  = Prelude.map (wrapResult encode) (getTask baseUrl token.auth_token taskId)

||| Dispatch CmdChangeTaskStatus: change the status of a task.
dispatchChangeTaskStatus :
      HasIO io
   => (taskId : Nat64Id)
   -> (newStatus : Bits64)
   -> (ver : Version)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchChangeTaskStatus _ _ _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchChangeTaskStatus _ _ _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchChangeTaskStatus taskId newSt ver (Just token) (Just baseUrl)
  = Prelude.map (wrapResult encode) (changeTaskStatus baseUrl token.auth_token taskId newSt ver)

||| Dispatch CmdTaskComment: add a comment to a task.
dispatchTaskComment :
      HasIO io
   => (taskId : Nat64Id)
   -> (text : String)
   -> (ver : Version)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchTaskComment _ _ _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchTaskComment _ _ _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchTaskComment taskId txt ver (Just token) (Just baseUrl)
  = Prelude.map (wrapResult (JSON.ToJSON.encode)) (taskComment baseUrl token.auth_token taskId txt ver)

||| Dispatch CmdListProjects: list projects the user can access.
dispatchListProjects :
      HasIO io
   => (member : Maybe String)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchListProjects _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchListProjects _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchListProjects member (Just token) (Just baseUrl)
  = Prelude.map (wrapResult encode) (listProjects baseUrl token.auth_token member Nothing Nothing)

||| Dispatch CmdGetProject: get project by ID or slug.
dispatchGetProject :
      HasIO io
   => (id : Maybe Nat64Id)
   -> (slug : Maybe Slug)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchGetProject _ _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchGetProject _ _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchGetProject (Just id) _ (Just token) (Just baseUrl)
  = Prelude.map (wrapResult encode) (getProjectById baseUrl token.auth_token id)
dispatchGetProject _ (Just slug) (Just token) (Just baseUrl)
  = Prelude.map (wrapResult encode) (getProjectBySlug baseUrl token.auth_token slug)
dispatchGetProject _ _ _ _ = pure $ Err $ MkErrorResponse False "bad_request" "Must provide id or slug"

||| Dispatch CmdListEpics: list epics in a project.
dispatchListEpics :
      HasIO io
   => (project : String)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchListEpics _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchListEpics _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchListEpics project (Just token) (Just baseUrl)
  = Prelude.map (wrapResult encode) (listEpics baseUrl token.auth_token project Nothing Nothing)

||| Dispatch CmdGetEpic: get epic by ID.
dispatchGetEpic :
      HasIO io
   => (id : Maybe Nat64Id)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchGetEpic Nothing _ _ = pure $ Err $ MkErrorResponse False "bad_request" "No epic ID provided"
dispatchGetEpic _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchGetEpic _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchGetEpic (Just id) (Just token) (Just baseUrl)
  = Prelude.map (wrapResult encode) (getEpic baseUrl token.auth_token id)

||| Dispatch CmdListStories: list user stories in a project.
dispatchListStories :
      HasIO io
   => (project : String)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchListStories _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchListStories _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchListStories project (Just token) (Just baseUrl)
  = Prelude.map (wrapResult encode) (listStories baseUrl token.auth_token project Nothing Nothing)

||| Dispatch CmdGetStory: get user story by ID.
dispatchGetStory :
      HasIO io
   => (id : Maybe Nat64Id)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchGetStory Nothing _ _ = pure $ Err $ MkErrorResponse False "bad_request" "No story ID provided"
dispatchGetStory _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchGetStory _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchGetStory (Just id) (Just token) (Just baseUrl)
  = Prelude.map (wrapResult encode) (getStory baseUrl token.auth_token id)

||| Dispatch CmdListTasks: list tasks.
dispatchListTasks :
      HasIO io
   => (project : Maybe String)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchListTasks _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchListTasks _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchListTasks project (Just token) (Just baseUrl)
  = Prelude.map (wrapResult encode) (listTasks baseUrl token.auth_token project Nothing Nothing Nothing)

||| Dispatch CmdGetTask: get task by ID.
dispatchGetTask :
      HasIO io
   => (id : Maybe Nat64Id)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchGetTask Nothing _ _ = pure $ Err $ MkErrorResponse False "bad_request" "No task ID provided"
dispatchGetTask _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchGetTask _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchGetTask (Just id) (Just token) (Just baseUrl)
  = Prelude.map (wrapResult encode) (getTask baseUrl token.auth_token id)

||| Dispatch CmdListIssues: list issues in a project.
dispatchListIssues :
      HasIO io
   => (project : String)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchListIssues _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchListIssues _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchListIssues project (Just token) (Just baseUrl)
  = Prelude.map (wrapResult encode) (listIssues baseUrl token.auth_token project Nothing Nothing)

||| Dispatch CmdGetIssue: get issue by ID.
dispatchGetIssue :
      HasIO io
   => (id : Maybe Nat64Id)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchGetIssue Nothing _ _ = pure $ Err $ MkErrorResponse False "bad_request" "No issue ID provided"
dispatchGetIssue _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchGetIssue _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchGetIssue (Just id) (Just token) (Just baseUrl)
  = Prelude.map (wrapResult encode) (getIssue baseUrl token.auth_token id)

||| Dispatch CmdListWiki: list wiki pages in a project.
dispatchListWiki :
      HasIO io
   => (project : String)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchListWiki _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchListWiki _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchListWiki project (Just token) (Just baseUrl)
  = Prelude.map (wrapResult encode) (listWiki baseUrl token.auth_token project Nothing Nothing)

||| Dispatch CmdGetWiki: get wiki page by ID.
dispatchGetWiki :
      HasIO io
   => (id : Maybe Nat64Id)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchGetWiki Nothing _ _ = pure $ Err $ MkErrorResponse False "bad_request" "No wiki ID provided"
dispatchGetWiki _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchGetWiki _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchGetWiki (Just id) (Just token) (Just baseUrl)
  = Prelude.map (wrapResult encode) (getWiki baseUrl token.auth_token id)

||| Dispatch CmdListMilestones: list milestones in a project.
dispatchListMilestones :
      HasIO io
   => (project : String)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchListMilestones _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchListMilestones _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchListMilestones project (Just token) (Just baseUrl)
  = Prelude.map (wrapResult encode) (listMilestones baseUrl token.auth_token project Nothing Nothing)

||| Dispatch CmdListUsers: list project members.
dispatchListUsers :
      HasIO io
   => (project : String)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchListUsers _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchListUsers _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchListUsers project (Just token) (Just baseUrl)
  = Prelude.map (wrapResult encode) (listUsers baseUrl token.auth_token project)

||| Dispatch CmdListMemberships: list project memberships.
dispatchListMemberships :
      HasIO io
   => (project : String)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchListMemberships _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchListMemberships _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchListMemberships project (Just token) (Just baseUrl)
  = Prelude.map (wrapResult encode) (listMemberships baseUrl token.auth_token project)

||| Dispatch CmdListRoles: list project roles.
dispatchListRoles :
      HasIO io
   => (project : String)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchListRoles _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchListRoles _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchListRoles project (Just token) (Just baseUrl)
  = Prelude.map (wrapResult encode) (listRoles baseUrl token.auth_token project)

||| Dispatch CmdSearch: search within a project.
dispatchSearch :
      HasIO io
   => (project : String)
   -> (text : String)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchSearch _ _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchSearch _ _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchSearch project text (Just token) (Just baseUrl)
  = Prelude.map (wrapResult id) (search baseUrl token.auth_token project text)

||| Dispatch CmdResolve: resolve an entity ref.
dispatchResolve :
      HasIO io
   => (project : String)
   -> (ref : String)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchResolve _ _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchResolve _ _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchResolve project ref (Just token) (Just baseUrl)
  = Prelude.map (wrapResult id) (resolve baseUrl token.auth_token project ref)

||| Dispatch CmdListComments: list history entries for an entity.
dispatchListComments :
      HasIO io
   => (entity : String)
   -> (entityId : Nat64Id)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchListComments _ _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchListComments _ _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchListComments entity eid (Just token) (Just baseUrl)
  = Prelude.map (wrapResult encode) (listHistory baseUrl token.auth_token entity eid)

||| Dispatch CmdCreateEpic: create a new epic.
dispatchCreateEpic :
      HasIO io
   => (project : String)
   -> (subject : String)
   -> (description : Maybe String)
   -> (status : Maybe String)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchCreateEpic _ _ _ _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchCreateEpic _ _ _ _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchCreateEpic project subject desc stat (Just token) (Just baseUrl)
  = Prelude.map (wrapResult encode) (createEpic baseUrl token.auth_token project subject desc stat)

||| Dispatch CmdUpdateEpic: update an existing epic.
dispatchUpdateEpic :
      HasIO io
   => (id : Nat64Id)
   -> (subject : Maybe String)
   -> (description : Maybe String)
   -> (status : Maybe String)
   -> (ver : Version)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchUpdateEpic _ _ _ _ _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchUpdateEpic _ _ _ _ _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchUpdateEpic id subj desc stat ver (Just token) (Just baseUrl)
  = Prelude.map (wrapResult encode) (updateEpic baseUrl token.auth_token id subj desc stat ver)

||| Dispatch CmdDeleteEpic: delete an epic.
dispatchDeleteEpic :
      HasIO io
   => (id : Nat64Id)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchDeleteEpic _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchDeleteEpic _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchDeleteEpic id (Just token) (Just baseUrl)
  = Prelude.map (wrapResult (const "deleted")) (deleteEpic baseUrl token.auth_token id)

||| Dispatch CmdCreateStory: create a new user story.
dispatchCreateStory :
      HasIO io
   => (project : String)
   -> (subject : String)
   -> (description : Maybe String)
   -> (milestone : Maybe Nat64Id)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchCreateStory _ _ _ _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchCreateStory _ _ _ _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchCreateStory project subject desc mstone (Just token) (Just baseUrl)
  = Prelude.map (wrapResult encode) (createStory baseUrl token.auth_token project subject desc mstone)

||| Dispatch CmdUpdateStory: update an existing user story.
dispatchUpdateStory :
      HasIO io
   => (id : Nat64Id)
   -> (subject : Maybe String)
   -> (description : Maybe String)
   -> (milestone : Maybe String)
   -> (ver : Version)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchUpdateStory _ _ _ _ _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchUpdateStory _ _ _ _ _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchUpdateStory id subj desc mstone ver (Just token) (Just baseUrl)
  = Prelude.map (wrapResult encode) (updateStory baseUrl token.auth_token id subj desc mstone ver)

||| Dispatch CmdDeleteStory: delete a user story.
dispatchDeleteStory :
      HasIO io
   => (id : Nat64Id)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchDeleteStory _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchDeleteStory _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchDeleteStory id (Just token) (Just baseUrl)
  = Prelude.map (wrapResult (const "deleted")) (deleteStory baseUrl token.auth_token id)

||| Dispatch CmdCreateTask: create a new task.
dispatchCreateTask :
      HasIO io
   => (project : String)
   -> (subject : String)
   -> (story : Maybe Nat64Id)
   -> (description : Maybe String)
   -> (status : Maybe String)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchCreateTask _ _ _ _ _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchCreateTask _ _ _ _ _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchCreateTask project subject story desc stat (Just token) (Just baseUrl)
  = Prelude.map (wrapResult encode) (createTask baseUrl token.auth_token project subject story desc stat)

||| Dispatch CmdUpdateTask: update an existing task.
dispatchUpdateTask :
      HasIO io
   => (id : Nat64Id)
   -> (subject : Maybe String)
   -> (description : Maybe String)
   -> (status : Maybe String)
   -> (ver : Version)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchUpdateTask _ _ _ _ _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchUpdateTask _ _ _ _ _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchUpdateTask id subj desc stat ver (Just token) (Just baseUrl)
  = Prelude.map (wrapResult encode) (updateTask baseUrl token.auth_token id subj desc stat ver)

||| Dispatch CmdDeleteTask: delete a task.
dispatchDeleteTask :
      HasIO io
   => (id : Nat64Id)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchDeleteTask _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchDeleteTask _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchDeleteTask id (Just token) (Just baseUrl)
  = Prelude.map (wrapResult (const "deleted")) (deleteTask baseUrl token.auth_token id)

||| Dispatch CmdCreateIssue: create a new issue.
dispatchCreateIssue :
      HasIO io
   => (project : String)
   -> (subject : String)
   -> (description : Maybe String)
   -> (priority : Maybe String)
   -> (severity : Maybe String)
   -> (issueType : Maybe String)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchCreateIssue _ _ _ _ _ _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchCreateIssue _ _ _ _ _ _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchCreateIssue project subject desc prio sev itype (Just token) (Just baseUrl)
  = Prelude.map (wrapResult encode) (createIssue baseUrl token.auth_token project subject desc prio sev itype)

||| Dispatch CmdUpdateIssue: update an existing issue.
dispatchUpdateIssue :
      HasIO io
   => (id : Nat64Id)
   -> (subject : Maybe String)
   -> (description : Maybe String)
   -> (issueType : Maybe String)
   -> (ver : Version)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchUpdateIssue _ _ _ _ _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchUpdateIssue _ _ _ _ _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchUpdateIssue id subj desc itype ver (Just token) (Just baseUrl)
  = Prelude.map (wrapResult encode) (updateIssue baseUrl token.auth_token id subj desc itype ver)

||| Dispatch CmdDeleteIssue: delete an issue.
dispatchDeleteIssue :
      HasIO io
   => (id : Nat64Id)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchDeleteIssue _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchDeleteIssue _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchDeleteIssue id (Just token) (Just baseUrl)
  = Prelude.map (wrapResult (const "deleted")) (deleteIssue baseUrl token.auth_token id)

||| Dispatch CmdCreateWiki: create a new wiki page.
dispatchCreateWiki :
      HasIO io
   => (project : String)
   -> (slug : String)
   -> (content : String)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchCreateWiki _ _ _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchCreateWiki _ _ _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchCreateWiki project slug content (Just token) (Just baseUrl)
  = Prelude.map (wrapResult encode) (createWiki baseUrl token.auth_token project slug content)

||| Dispatch CmdUpdateWiki: update an existing wiki page.
dispatchUpdateWiki :
      HasIO io
   => (id : Nat64Id)
   -> (content : Maybe String)
   -> (slug : Maybe String)
   -> (ver : Version)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchUpdateWiki _ _ _ _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchUpdateWiki _ _ _ _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchUpdateWiki id content slug ver (Just token) (Just baseUrl)
  = Prelude.map (wrapResult encode) (updateWiki baseUrl token.auth_token id content slug ver)

||| Dispatch CmdDeleteWiki: delete a wiki page.
dispatchDeleteWiki :
      HasIO io
   => (id : Nat64Id)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchDeleteWiki _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchDeleteWiki _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchDeleteWiki id (Just token) (Just baseUrl)
  = Prelude.map (wrapResult (const "deleted")) (deleteWiki baseUrl token.auth_token id)

||| Dispatch CmdCreateMilestone: create a new milestone.
dispatchCreateMilestone :
      HasIO io
   => (project : String)
   -> (name : String)
   -> (estimatedStart : String)
   -> (estimatedFinish : String)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchCreateMilestone _ _ _ _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchCreateMilestone _ _ _ _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchCreateMilestone project name estStart estFinish (Just token) (Just baseUrl)
  = Prelude.map (wrapResult encode) (createMilestone baseUrl token.auth_token project name estStart estFinish)

||| Dispatch CmdUpdateMilestone: update an existing milestone.
dispatchUpdateMilestone :
      HasIO io
   => (id : Nat64Id)
   -> (name : Maybe String)
   -> (estimatedStart : Maybe String)
   -> (estimatedFinish : Maybe String)
   -> (ver : Version)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchUpdateMilestone _ _ _ _ _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchUpdateMilestone _ _ _ _ _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchUpdateMilestone id name estStart estFinish ver (Just token) (Just baseUrl)
  = Prelude.map (wrapResult encode) (updateMilestone baseUrl token.auth_token id name estStart estFinish ver)

||| Dispatch CmdComment: add a comment to an entity.
dispatchComment :
      HasIO io
   => (entity : String)
   -> (entityId : Nat64Id)
   -> (text : String)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchComment _ _ _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchComment _ _ _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchComment entity eid txt (Just token) (Just baseUrl)
  = Prelude.map (wrapResult id) (addComment baseUrl token.auth_token entity eid txt 0)

||| Dispatch CmdEditComment: edit an existing comment.
dispatchEditComment :
      HasIO io
   => (entity : String)
   -> (entityId : Nat64Id)
   -> (commentId : Nat64Id)
   -> (text : String)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchEditComment _ _ _ _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchEditComment _ _ _ _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchEditComment entity eid cid txt (Just token) (Just baseUrl)
  = Prelude.map (wrapResult id) (editComment baseUrl token.auth_token entity eid (show cid.id) txt)

||| Dispatch CmdDeleteComment: delete a comment.
dispatchDeleteComment :
      HasIO io
   => (entity : String)
   -> (entityId : Nat64Id)
   -> (commentId : Nat64Id)
   -> (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchDeleteComment _ _ _ Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchDeleteComment _ _ _ _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchDeleteComment entity eid cid (Just token) (Just baseUrl)
  = Prelude.map (wrapResult (const "deleted")) (deleteComment baseUrl token.auth_token entity eid (show cid.id))

||| Parse a command name and JSON arguments into a Command.
public export
parseCommand : (cmd : String) -> (args : String) -> Either String Command
parseCommand "me"      _ = pure CmdMe
parseCommand "login"   args = case decodeEither args of
                                 Left  err  => Left err
                                 Right c   => pure $ CmdLogin c
parseCommand "refresh" args = case decodeEither args of
                                 Left  err  => Left err
                                 Right r    => pure $ CmdRefresh r.refresh
parseCommand cmd _    = Left $ "Unknown command: " ++ cmd

||| Dispatch a parsed Command together with auth and base URL,
||| returning a Response.
public export
dispatchCommand :
      HasIO io =>
      (command : Command)
   -> (auth  : Maybe Model.Auth.Token)
   -> (base  : Maybe String)
   -> io Response
dispatchCommand command auth base
   = case command of
        CmdLogin creds                                   => dispatchLogin creds base
        CmdRefresh rtok                                   => dispatchRefresh rtok base
        CmdMe                                            => dispatchMe auth base
        CmdListProjects member                            => dispatchListProjects member auth base
        CmdGetProject mid mslug                           => dispatchGetProject mid mslug auth base
        CmdListEpics project                              => dispatchListEpics project auth base
        CmdGetEpic eid                                   => dispatchGetEpic eid auth base
        CmdListStories project                            => dispatchListStories project auth base
        CmdGetStory sid                                  => dispatchGetStory sid auth base
        CmdListTasks project                              => dispatchListTasks project auth base
        CmdGetTask tid                                   => dispatchGetTask tid auth base
        CmdListIssues project                             => dispatchListIssues project auth base
        CmdGetIssue iid                                  => dispatchGetIssue iid auth base
        CmdListWiki project                               => dispatchListWiki project auth base
        CmdGetWiki wid                                   => dispatchGetWiki wid auth base
        CmdListMilestones project                         => dispatchListMilestones project auth base
        CmdListUsers project                              => dispatchListUsers project auth base
        CmdListMemberships project                        => dispatchListMemberships project auth base
        CmdListRoles project                              => dispatchListRoles project auth base
        CmdSearch project text                            => dispatchSearch project text auth base
        CmdResolve project ref                            => dispatchResolve project ref auth base
        CmdCreateEpic project subject desc stat           => dispatchCreateEpic project subject desc stat auth base
        CmdUpdateEpic id subj desc stat ver               => dispatchUpdateEpic id subj desc stat ver auth base
        CmdDeleteEpic id                                 => dispatchDeleteEpic id auth base
        CmdCreateStory project subject desc mstone        => dispatchCreateStory project subject desc mstone auth base
        CmdUpdateStory id subj desc mstone ver            => dispatchUpdateStory id subj desc mstone ver auth base
        CmdDeleteStory id                                => dispatchDeleteStory id auth base
        CmdCreateTask project subject story desc stat     => dispatchCreateTask project subject story desc stat auth base
        CmdUpdateTask id subj desc stat ver               => dispatchUpdateTask id subj desc stat ver auth base
        CmdDeleteTask id                                 => dispatchDeleteTask id auth base
        CmdWatchTask tid                                 => dispatchWatchTask tid auth base
        CmdChangeTaskStatus tid st ver                    => dispatchChangeTaskStatus tid st ver auth base
        CmdTaskComment tid txt ver                        => dispatchTaskComment tid txt ver auth base
        CmdCreateIssue project subject desc prio sev itype => dispatchCreateIssue project subject desc prio sev itype auth base
        CmdUpdateIssue id subj desc itype ver             => dispatchUpdateIssue id subj desc itype ver auth base
        CmdDeleteIssue id                                => dispatchDeleteIssue id auth base
        CmdCreateWiki project slug content                => dispatchCreateWiki project slug content auth base
        CmdUpdateWiki id content slug ver                 => dispatchUpdateWiki id content slug ver auth base
        CmdDeleteWiki id                                 => dispatchDeleteWiki id auth base
        CmdCreateMilestone project name es ef             => dispatchCreateMilestone project name es ef auth base
        CmdUpdateMilestone id name es ef ver              => dispatchUpdateMilestone id name es ef ver auth base
        CmdComment entity eid text                        => dispatchComment entity eid text auth base
        CmdEditComment entity eid cid text                => dispatchEditComment entity eid cid text auth base
        CmdDeleteComment entity eid cid                  => dispatchDeleteComment entity eid cid auth base
        CmdListComments entity eid                        => dispatchListComments entity eid auth base
