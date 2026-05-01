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
import Taiga.Env


%language ElabReflection

||| Refresh token argument wrapper.
record RefreshArgs where
  constructor MkRefreshArgs
  refresh : String
  refreshArgsTag : String

%runElab derive "RefreshArgs" [Show,FromJSON]

||| --- Argument records for agent-mode command parsing ---

||| Arguments for listing projects.
record ListProjectsArgs where
  constructor MkListProjectsArgs
  member : Maybe String
  listProjectsTag : String

%runElab derive "ListProjectsArgs" [Show,FromJSON]

||| Arguments for fetching a project by ID or slug.
record GetProjectArgs where
  constructor MkGetProjectArgs
  id : Maybe Bits64
  slug : Maybe String
%runElab derive "GetProjectArgs" [Show,FromJSON]

||| Simple wrapper holding a single required project string.
record StringArgs where
  constructor MkStringArgs
  project : String
  stringArgsTag : String

%runElab derive "StringArgs" [Show,FromJSON]

||| Simple wrapper holding an optional project string.
record MaybeStringArgs where
  constructor MkMaybeStringArgs
  project : Maybe String
  maybeStringArgsTag : String

%runElab derive "MaybeStringArgs" [Show,FromJSON]

||| Simple wrapper holding an optional entity ID.
record MaybeNat64Args where
  constructor MkMaybeNat64Args
  id : Maybe Bits64
  maybeNat64ArgsTag : String

%runElab derive "MaybeNat64Args" [Show,FromJSON]

||| Simple wrapper holding a required entity ID.
record Nat64Args where
  constructor MkNat64Args
  id : Bits64
  nat64ArgsTag : String

%runElab derive "Nat64Args" [Show,FromJSON]

||| Arguments for project-wide text search.
record SearchArgs where
  constructor MkSearchArgs
  project : String
  text : String
%runElab derive "SearchArgs" [Show,FromJSON]

||| Arguments for resolving an entity ref to its ID.
record ResolveArgs where
  constructor MkResolveArgs
  project : String
  ref : String
%runElab derive "ResolveArgs" [Show,FromJSON]

||| Arguments for creating a new epic.
record CreateEpicArgs where
  constructor MkCreateEpicArgs
  project : String
  subject : String
  description : Maybe String
  status : Maybe String
%runElab derive "CreateEpicArgs" [Show,FromJSON]

||| Arguments for updating an existing epic.
record UpdateEpicArgs where
  constructor MkUpdateEpicArgs
  id : Bits64
  subject : Maybe String
  description : Maybe String
  status : Maybe String
  version : Bits32
%runElab derive "UpdateEpicArgs" [Show,FromJSON]

||| Arguments for creating a new user story.
record CreateStoryArgs where
  constructor MkCreateStoryArgs
  project : String
  subject : String
  description : Maybe String
  milestone : Maybe Bits64
%runElab derive "CreateStoryArgs" [Show,FromJSON]

||| Arguments for updating an existing user story.
record UpdateStoryArgs where
  constructor MkUpdateStoryArgs
  id : Bits64
  subject : Maybe String
  description : Maybe String
  milestone : Maybe String
  version : Bits32
%runElab derive "UpdateStoryArgs" [Show,FromJSON]

||| Arguments for creating a new task.
record CreateTaskArgs where
  constructor MkCreateTaskArgs
  project : String
  subject : String
  story : Maybe Bits64
  description : Maybe String
  status : Maybe String
  milestone : Maybe Bits64

%runElab derive "CreateTaskArgs" [Show,FromJSON]

||| Arguments for updating an existing task.
record UpdateTaskArgs where
  constructor MkUpdateTaskArgs
  id : Bits64
  subject : Maybe String
  description : Maybe String
  status : Maybe String
  version : Bits32
%runElab derive "UpdateTaskArgs" [Show,FromJSON]

||| Arguments for changing a task's status.
record ChangeTaskStatusArgs where
  constructor MkChangeTaskStatusArgs
  id : Bits64
  status : Bits64
  version : Bits32
%runElab derive "ChangeTaskStatusArgs" [Show,FromJSON]

||| Arguments for adding a comment to a task.
record TaskCommentArgs where
  constructor MkTaskCommentArgs
  id : Bits64
  text : String
  version : Bits32
%runElab derive "TaskCommentArgs" [Show,FromJSON]

||| Arguments for creating a new issue.
record CreateIssueArgs where
  constructor MkCreateIssueArgs
  project : String
  subject : String
  description : Maybe String
  priority : Maybe String
  severity : Maybe String
  type : Maybe String
%runElab derive "CreateIssueArgs" [Show,FromJSON]

||| Arguments for updating an existing issue.
record UpdateIssueArgs where
  constructor MkUpdateIssueArgs
  id : Bits64
  subject : Maybe String
  description : Maybe String
  type : Maybe String
  status : Maybe String
  version : Bits32
%runElab derive "UpdateIssueArgs" [Show,FromJSON]

||| Arguments for creating a new wiki page.
record CreateWikiArgs where
  constructor MkCreateWikiArgs
  project : String
  slug : String
  content : String
%runElab derive "CreateWikiArgs" [Show,FromJSON]

||| Arguments for updating an existing wiki page.
record UpdateWikiArgs where
  constructor MkUpdateWikiArgs
  id : Bits64
  content : Maybe String
  slug : Maybe String
  version : Bits32
%runElab derive "UpdateWikiArgs" [Show,FromJSON]

||| Arguments identifying a generic entity by type and ID.
record EntityIdArgs where
  constructor MkEntityIdArgs
  entity : String
  id : Bits64
%runElab derive "EntityIdArgs" [Show,FromJSON]

||| Arguments for adding a comment to any entity.
record CommentArgs where
  constructor MkCommentArgs
  entity : String
  id : Bits64
  text : String
%runElab derive "CommentArgs" [Show,FromJSON]

||| Arguments for creating a new milestone.
record CreateMilestoneArgs where
  constructor MkCreateMilestoneArgs
  project : String
  name : String
  estimated_start : String
  estimated_finish : String
%runElab derive "CreateMilestoneArgs" [Show,FromJSON]

||| Arguments for updating an existing milestone.
record UpdateMilestoneArgs where
  constructor MkUpdateMilestoneArgs
  id : Bits64
  name : Maybe String
  estimated_start : Maybe String
  estimated_finish : Maybe String
  version : Bits32
%runElab derive "UpdateMilestoneArgs" [Show,FromJSON]

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
  CmdCreateTask     : String -> String -> Maybe Nat64Id -> Maybe String -> Maybe String -> Maybe Bits64 -> Command
  CmdUpdateTask     : Nat64Id -> Maybe String -> Maybe String -> Maybe String -> Version -> Command
  CmdDeleteTask     : Nat64Id -> Command
  CmdWatchTask      : Nat64Id -> Command
  CmdChangeTaskStatus : Nat64Id -> Bits64 -> Version -> Command
  CmdTaskComment    : Nat64Id -> String -> Version -> Command

  -- Write / mutation commands — issues
  CmdCreateIssue : String -> String -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> Command
  CmdUpdateIssue : Nat64Id -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> Version -> Command
  CmdDeleteIssue : Nat64Id -> Command

  -- Write / mutation commands — wiki
  CmdCreateWiki : String -> String -> String -> Command
  CmdUpdateWiki : Nat64Id -> Maybe String -> Maybe String -> Version -> Command
  CmdDeleteWiki : Nat64Id -> Command

  -- Comments (via history API)
  CmdComment      : String -> Nat64Id -> String -> Command
  CmdListComments : String -> Nat64Id -> Command

  -- Milestones
  CmdCreateMilestone : String -> String -> Maybe String -> Maybe String -> Command
  CmdUpdateMilestone : Nat64Id -> Maybe String -> Maybe String -> Maybe String -> Version -> Command
  CmdDeleteMilestone : Nat64Id -> Command

%runElab derive "Command" [Show,ToJSON,FromJSON]

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
  Prelude.map (wrapResult encode) (login baseUrl creds)

||| Helper: dispatch refresh (no auth needed, just base URL).
private dispatchRefresh' :
      HasIO io
   => String -> Maybe String -> io Response
dispatchRefresh' _ Nothing =
  pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchRefresh' refreshTok (Just baseUrl) =
  Prelude.map (wrapResult encode) (refreshToken baseUrl refreshTok)

||| Helper: decode JSON string into type a, then construct Command.
private parseCmdArgs : FromJSON a => (a -> Command) -> String -> Either String Command
parseCmdArgs fn = Prelude.map fn . decodeEither

private mkRefreshCmd        : RefreshArgs -> Command
mkRefreshCmd r              = CmdRefresh r.refresh

private mkListProjectsCmd   : ListProjectsArgs -> Command
mkListProjectsCmd a         = CmdListProjects a.member

private mkGetProjectCmd     : GetProjectArgs -> Command
mkGetProjectCmd a           = CmdGetProject (map MkNat64Id a.id) (map MkSlug a.slug)

private mkListEpicsCmd      : StringArgs -> Command
mkListEpicsCmd a            = CmdListEpics a.project

private mkGetEpicCmd        : MaybeNat64Args -> Command
mkGetEpicCmd a              = CmdGetEpic (map MkNat64Id a.id)

private mkListStoriesCmd    : StringArgs -> Command
mkListStoriesCmd a          = CmdListStories a.project

private mkGetStoryCmd       : MaybeNat64Args -> Command
mkGetStoryCmd a             = CmdGetStory (map MkNat64Id a.id)

private mkListTasksCmd      : MaybeStringArgs -> Command
mkListTasksCmd a            = CmdListTasks a.project

private mkGetTaskCmd        : MaybeNat64Args -> Command
mkGetTaskCmd a              = CmdGetTask (map MkNat64Id a.id)

private mkListIssuesCmd     : StringArgs -> Command
mkListIssuesCmd a           = CmdListIssues a.project

private mkGetIssueCmd       : MaybeNat64Args -> Command
mkGetIssueCmd a             = CmdGetIssue (map MkNat64Id a.id)

private mkListWikiCmd       : StringArgs -> Command
mkListWikiCmd a             = CmdListWiki a.project

private mkGetWikiCmd        : MaybeNat64Args -> Command
mkGetWikiCmd a              = CmdGetWiki (map MkNat64Id a.id)

private mkListMilestonesCmd : StringArgs -> Command
mkListMilestonesCmd a       = CmdListMilestones a.project

private mkListUsersCmd      : StringArgs -> Command
mkListUsersCmd a            = CmdListUsers a.project

private mkListMembershipsCmd: StringArgs -> Command
mkListMembershipsCmd a      = CmdListMemberships a.project

private mkListRolesCmd      : StringArgs -> Command
mkListRolesCmd a            = CmdListRoles a.project

private mkSearchCmd         : SearchArgs -> Command
mkSearchCmd a               = CmdSearch a.project a.text

private mkResolveCmd        : ResolveArgs -> Command
mkResolveCmd a              = CmdResolve a.project a.ref

private mkCreateEpicCmd     : CreateEpicArgs -> Command
mkCreateEpicCmd a           = CmdCreateEpic a.project a.subject a.description a.status

private mkUpdateEpicCmd     : UpdateEpicArgs -> Command
mkUpdateEpicCmd a           = CmdUpdateEpic (MkNat64Id a.id) a.subject a.description a.status (MkVersion a.version)

private mkDeleteEpicCmd     : Nat64Args -> Command
mkDeleteEpicCmd a           = CmdDeleteEpic (MkNat64Id a.id)

private mkCreateStoryCmd    : CreateStoryArgs -> Command
mkCreateStoryCmd a          = CmdCreateStory a.project a.subject a.description (map MkNat64Id a.milestone)


private mkUpdateStoryCmd    : UpdateStoryArgs -> Command
mkUpdateStoryCmd a          = CmdUpdateStory (MkNat64Id a.id) a.subject a.description a.milestone (MkVersion a.version)

private mkDeleteStoryCmd    : Nat64Args -> Command
mkDeleteStoryCmd a          = CmdDeleteStory (MkNat64Id a.id)

private mkCreateTaskCmd     : CreateTaskArgs -> Command
mkCreateTaskCmd a           =
  CmdCreateTask a.project a.subject (map MkNat64Id a.story) a.description a.status a.milestone

private mkUpdateTaskCmd     : UpdateTaskArgs -> Command
mkUpdateTaskCmd a           = CmdUpdateTask (MkNat64Id a.id) a.subject a.description a.status (MkVersion a.version)

private mkDeleteTaskCmd     : Nat64Args -> Command
mkDeleteTaskCmd a           = CmdDeleteTask (MkNat64Id a.id)

private mkWatchTaskCmd      : Nat64Args -> Command
mkWatchTaskCmd a            = CmdWatchTask (MkNat64Id a.id)

private mkChangeTaskStatusCmd : ChangeTaskStatusArgs -> Command
mkChangeTaskStatusCmd a     = CmdChangeTaskStatus (MkNat64Id a.id) a.status (MkVersion a.version)

private mkTaskCommentCmd    : TaskCommentArgs -> Command
mkTaskCommentCmd a          = CmdTaskComment (MkNat64Id a.id) a.text (MkVersion a.version)

private mkCreateIssueCmd    : CreateIssueArgs -> Command
mkCreateIssueCmd a          = CmdCreateIssue a.project a.subject a.description a.priority a.severity a.type

private mkUpdateIssueCmd    : UpdateIssueArgs -> Command
mkUpdateIssueCmd a          = CmdUpdateIssue (MkNat64Id a.id) a.subject a.description a.type a.status (MkVersion a.version)

private mkDeleteIssueCmd    : Nat64Args -> Command
mkDeleteIssueCmd a          = CmdDeleteIssue (MkNat64Id a.id)

private mkCreateWikiCmd     : CreateWikiArgs -> Command
mkCreateWikiCmd a           = CmdCreateWiki a.project a.slug a.content

private mkUpdateWikiCmd     : UpdateWikiArgs -> Command
mkUpdateWikiCmd a           = CmdUpdateWiki (MkNat64Id a.id) a.content a.slug (MkVersion a.version)

private mkDeleteWikiCmd     : Nat64Args -> Command
mkDeleteWikiCmd a           = CmdDeleteWiki (MkNat64Id a.id)

private mkCommentCmd        : CommentArgs -> Command
mkCommentCmd a              = CmdComment a.entity (MkNat64Id a.id) a.text

private mkListCommentsCmd   : EntityIdArgs -> Command
mkListCommentsCmd a         = CmdListComments a.entity (MkNat64Id a.id)
private mkCreateMilestoneCmd : CreateMilestoneArgs -> Command

mkCreateMilestoneCmd a      = CmdCreateMilestone a.project a.name (toMaybe a.estimated_start) (toMaybe a.estimated_finish)
  where
    toMaybe : String -> Maybe String
    toMaybe ""      = Nothing
    toMaybe str     = Just str

private mkUpdateMilestoneCmd : UpdateMilestoneArgs -> Command
mkUpdateMilestoneCmd a      = CmdUpdateMilestone (MkNat64Id a.id) a.name a.estimated_start a.estimated_finish (MkVersion a.version)

private mkDeleteMilestoneCmd : Nat64Args -> Command
mkDeleteMilestoneCmd a      = CmdDeleteMilestone (MkNat64Id a.id)

||| Parse a command name and JSON arguments into a Command.
public export
parseCommand : (cmd : String) -> (args : String) -> Either String Command
parseCommand "me"               _            = pure CmdMe
parseCommand "login"            args        = parseCmdArgs CmdLogin args
parseCommand "refresh"          args        = parseCmdArgs mkRefreshCmd args
parseCommand "list-projects"    args        = parseCmdArgs mkListProjectsCmd args
parseCommand "get-project"      args        = parseCmdArgs mkGetProjectCmd args
parseCommand "list-epics"       args        = parseCmdArgs mkListEpicsCmd args
parseCommand "get-epic"         args        = parseCmdArgs mkGetEpicCmd args
parseCommand "list-stories"     args        = parseCmdArgs mkListStoriesCmd args
parseCommand "get-story"        args        = parseCmdArgs mkGetStoryCmd args
parseCommand "list-tasks"       args        = parseCmdArgs mkListTasksCmd args
parseCommand "get-task"         args        = parseCmdArgs mkGetTaskCmd args
parseCommand "list-issues"      args        = parseCmdArgs mkListIssuesCmd args
parseCommand "get-issue"        args        = parseCmdArgs mkGetIssueCmd args
parseCommand "list-wiki"        args        = parseCmdArgs mkListWikiCmd args
parseCommand "get-wiki"         args        = parseCmdArgs mkGetWikiCmd args
parseCommand "list-milestones"  args        = parseCmdArgs mkListMilestonesCmd args
parseCommand "list-users"       args        = parseCmdArgs mkListUsersCmd args
parseCommand "list-memberships" args        = parseCmdArgs mkListMembershipsCmd args
parseCommand "list-roles"       args        = parseCmdArgs mkListRolesCmd args
parseCommand "search"           args        = parseCmdArgs mkSearchCmd args
parseCommand "resolve"          args        = parseCmdArgs mkResolveCmd args
parseCommand "create-epic"      args        = parseCmdArgs mkCreateEpicCmd args
parseCommand "update-epic"      args        = parseCmdArgs mkUpdateEpicCmd args
parseCommand "delete-epic"      args        = parseCmdArgs mkDeleteEpicCmd args
parseCommand "create-story"     args        = parseCmdArgs mkCreateStoryCmd args
parseCommand "update-story"     args        = parseCmdArgs mkUpdateStoryCmd args
parseCommand "delete-story"     args        = parseCmdArgs mkDeleteStoryCmd args
parseCommand "create-task"      args        = parseCmdArgs mkCreateTaskCmd args
parseCommand "update-task"      args        = parseCmdArgs mkUpdateTaskCmd args
parseCommand "delete-task"      args        = parseCmdArgs mkDeleteTaskCmd args
parseCommand "watch-task"       args        = parseCmdArgs mkWatchTaskCmd args
parseCommand "change-task-status" args      = parseCmdArgs mkChangeTaskStatusCmd args
parseCommand "task-comment"     args        = parseCmdArgs mkTaskCommentCmd args
parseCommand "create-issue"     args        = parseCmdArgs mkCreateIssueCmd args
parseCommand "update-issue"     args        = parseCmdArgs mkUpdateIssueCmd args
parseCommand "delete-issue"     args        = parseCmdArgs mkDeleteIssueCmd args
parseCommand "create-wiki"      args        = parseCmdArgs mkCreateWikiCmd args
parseCommand "update-wiki"      args        = parseCmdArgs mkUpdateWikiCmd args
parseCommand "delete-wiki"      args        = parseCmdArgs mkDeleteWikiCmd args
parseCommand "comment"          args        = parseCmdArgs mkCommentCmd args
parseCommand "list-comments"    args        = parseCmdArgs mkListCommentsCmd args
parseCommand "create-milestone" args        = parseCmdArgs mkCreateMilestoneCmd args
parseCommand "update-milestone" args        = parseCmdArgs mkUpdateMilestoneCmd args
parseCommand "delete-milestone" args        = parseCmdArgs mkDeleteMilestoneCmd args
parseCommand cmd _              = Left $ "Unknown command: " ++ cmd

||| Helper: wrap IO action result in a Response.
private dispatchWithEnvHelper :
      HasIO io
   => io (Either String a)
  -> (a -> String)
  -> io Response
dispatchWithEnvHelper action encFn = Prelude.map (wrapResult encFn) action

private dispatchWithEnv' :
      HasIO io
   => (command : Command)
  -> (env : ApiEnv)
  -> io Response
dispatchWithEnv' command env =
  case command of
        CmdMe                                              => dispatchWithEnvHelper (me env.base env.token) encode
        CmdListProjects member                             => dispatchWithEnvHelper (listProjects @{env} member Nothing Nothing) encode
        CmdGetProject (Just id) _                          => dispatchWithEnvHelper (getProjectById @{env} id) encode
        CmdGetProject _ (Just slug)                        => dispatchWithEnvHelper (getProjectBySlug @{env} slug) encode
        CmdGetProject Nothing Nothing                      => pure $ Err $ MkErrorResponse False "bad_request" "Must provide id or slug"
        CmdListEpics project                               => dispatchWithEnvHelper (listEpics @{env} project Nothing Nothing) encode
        CmdGetEpic (Just id)                              => dispatchWithEnvHelper (getEpic @{env} id) encode
        CmdGetEpic Nothing                                => pure $ Err $ MkErrorResponse False "bad_request" "No epic ID provided"
        CmdListStories project                             => dispatchWithEnvHelper (listStories @{env} project Nothing Nothing) encode
        CmdGetStory (Just id)                             => dispatchWithEnvHelper (getStory @{env} id) encode
        CmdGetStory Nothing                               => pure $ Err $ MkErrorResponse False "bad_request" "No story ID provided"
        CmdListTasks project                              => dispatchWithEnvHelper (listTasks @{env} project Nothing Nothing Nothing) encode
        CmdGetTask (Just id)                              => dispatchWithEnvHelper (getTask @{env} id) encode
        CmdGetTask Nothing                                => pure $ Err $ MkErrorResponse False "bad_request" "No task ID provided"
        CmdListIssues project                             => dispatchWithEnvHelper (listIssues @{env} project Nothing Nothing) encode
        CmdGetIssue (Just id)                             => dispatchWithEnvHelper (getIssue @{env} id) encode
        CmdGetIssue Nothing                               => pure $ Err $ MkErrorResponse False "bad_request" "No issue ID provided"
        CmdListWiki project                               => dispatchWithEnvHelper (listWiki @{env} project Nothing Nothing) encode
        CmdGetWiki (Just id)                              => dispatchWithEnvHelper (getWiki @{env} id) encode
        CmdGetWiki Nothing                                => pure $ Err $ MkErrorResponse False "bad_request" "No wiki ID provided"
        CmdListMilestones project                         => dispatchWithEnvHelper (listMilestones @{env} project Nothing Nothing) encode
        CmdListUsers project                              => dispatchWithEnvHelper (listUsers @{env} project) encode
        CmdListMemberships project                        => dispatchWithEnvHelper (listMemberships @{env} project) encode
        CmdListRoles project                              => dispatchWithEnvHelper (listRoles @{env} project) encode
        CmdSearch project text                            => dispatchWithEnvHelper (search @{env} project text) Prelude.id
        CmdResolve project ref                            => dispatchWithEnvHelper (resolve @{env} project ref) Prelude.id
        CmdCreateEpic p s d st                            => dispatchWithEnvHelper (createEpic @{env} p s d st) encode
        CmdUpdateEpic id sj d st v                        => dispatchWithEnvHelper (updateEpic @{env} id sj d st v) encode
        CmdDeleteEpic id                                  => dispatchWithEnvHelper (deleteEpic @{env} id) (const "deleted")
        CmdCreateStory p s d m                            => dispatchWithEnvHelper (createStory @{env} p s d m) encode
        CmdUpdateStory id sj d m v                        => dispatchWithEnvHelper (updateStory @{env} id sj d m v) encode
        CmdDeleteStory id                                 => dispatchWithEnvHelper (deleteStory @{env} id) (const "deleted")
        CmdCreateTask p s st d ss ms                      => dispatchWithEnvHelper (createTask @{env} p s st d ss ms) encode
        CmdUpdateTask id sj d st v                        => dispatchWithEnvHelper (updateTask @{env} id sj d st v) encode
        CmdDeleteTask id                                  => dispatchWithEnvHelper (deleteTask @{env} id) (const "deleted")
        CmdWatchTask tid                                  => dispatchWithEnvHelper (getTask @{env} tid) encode
        CmdChangeTaskStatus tid st v                      => dispatchWithEnvHelper (changeTaskStatus @{env} tid st v) encode
        CmdTaskComment tid txt v                          => dispatchWithEnvHelper (taskComment @{env} tid txt v) Prelude.id
        CmdCreateIssue p s d pr sv it                     => dispatchWithEnvHelper (createIssue @{env} p s d pr sv it) encode
        CmdUpdateIssue id sj d it st v                    => dispatchWithEnvHelper (updateIssue @{env} id sj d it st v) encode
        CmdDeleteIssue id                                 => dispatchWithEnvHelper (deleteIssue @{env} id) (const "deleted")
        CmdCreateWiki p sl c                              => dispatchWithEnvHelper (createWiki @{env} p sl c) encode
        CmdUpdateWiki id c sl v                           => dispatchWithEnvHelper (updateWiki @{env} id c sl v) encode
        CmdDeleteWiki id                                  => dispatchWithEnvHelper (deleteWiki @{env} id) (const "deleted")
        CmdCreateMilestone p n es ef                      => dispatchWithEnvHelper (createMilestone @{env} p n es ef) encode
        CmdUpdateMilestone id n es ef v                   => dispatchWithEnvHelper (updateMilestone @{env} id n es ef v) encode
        CmdDeleteMilestone id                             => dispatchWithEnvHelper (deleteMilestone @{env} id) (const "deleted")
        CmdComment e eid t                                => dispatchWithEnvHelper (addComment @{env} e eid t 0) Prelude.id
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
