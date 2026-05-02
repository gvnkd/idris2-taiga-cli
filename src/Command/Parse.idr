||| Parsing from command name + JSON arguments to Command sum type.
module Command.Parse

import Command.Types
import Model.Auth
import Model.Common
import JSON.FromJSON
import Data.Either
import Data.String

%language ElabReflection

||| Helper: decode JSON string into type a, then construct Command.
private parseCmdArgs : FromJSON a => (a -> Command) -> String -> Either String Command
parseCmdArgs fn = map fn . decodeEither

private mkRefreshCmd        : RefreshArgs -> Command
mkRefreshCmd r              = CmdRefresh r.refresh

private mkListProjectsCmd   : ListProjectsArgs -> Command
mkListProjectsCmd a         = CmdListProjects a.member

private mkGetProjectCmd     : GetProjectArgs -> Command
mkGetProjectCmd a           = CmdGetProject (map MkNat64Id a.id) (map MkSlug a.slug)

private mkListEpicsCmd      : ListArgs -> Command
mkListEpicsCmd a            = CmdListEpics a

private mkGetEpicCmd        : MaybeNat64Args -> Command
mkGetEpicCmd a              = CmdGetEpic (map MkNat64Id a.id)

private mkListStoriesCmd    : ListArgs -> Command
mkListStoriesCmd a          = CmdListStories a

private mkGetStoryCmd       : MaybeNat64Args -> Command
mkGetStoryCmd a             = CmdGetStory (map MkNat64Id a.id)

private mkListTasksCmd      : ListArgs -> Command
mkListTasksCmd a            = CmdListTasks a

private mkGetTaskCmd        : MaybeNat64Args -> Command
mkGetTaskCmd a              = CmdGetTask (map MkNat64Id a.id)

private mkListIssuesCmd     : ListArgs -> Command
mkListIssuesCmd a           = CmdListIssues a

private mkGetIssueCmd       : MaybeNat64Args -> Command
mkGetIssueCmd a             = CmdGetIssue (map MkNat64Id a.id)

private mkListWikiCmd       : ListArgs -> Command
mkListWikiCmd a             = CmdListWiki a

private mkGetWikiCmd        : MaybeNat64Args -> Command
mkGetWikiCmd a              = CmdGetWiki (map MkNat64Id a.id)

private mkListMilestonesCmd : ListArgs -> Command
mkListMilestonesCmd a       = CmdListMilestones a

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
mkUpdateEpicCmd a =
  CmdUpdateEpic (MkNat64Id a.id) a.subject a.description a.status (MkVersion a.version)

private mkDeleteEpicCmd     : Nat64Args -> Command
mkDeleteEpicCmd a           = CmdDeleteEpic (MkNat64Id a.id)

private mkCreateStoryCmd    : CreateStoryArgs -> Command
mkCreateStoryCmd a =
  CmdCreateStory a.project a.subject a.description (map MkNat64Id a.milestone)

private mkUpdateStoryCmd    : UpdateStoryArgs -> Command
mkUpdateStoryCmd a =
  CmdUpdateStory (MkNat64Id a.id) a.subject a.description a.milestone (MkVersion a.version)

private mkDeleteStoryCmd    : Nat64Args -> Command
mkDeleteStoryCmd a          = CmdDeleteStory (MkNat64Id a.id)

private mkCreateTaskCmd     : CreateTaskArgs -> Command
mkCreateTaskCmd a           =
  CmdCreateTask a.project a.subject (map MkNat64Id a.story) a.description a.status a.milestone

private mkUpdateTaskCmd     : UpdateTaskArgs -> Command
mkUpdateTaskCmd a =
  CmdUpdateTask (MkNat64Id a.id) a.subject a.description a.status (MkVersion a.version)

private mkDeleteTaskCmd     : Nat64Args -> Command
mkDeleteTaskCmd a           = CmdDeleteTask (MkNat64Id a.id)

private mkWatchTaskCmd      : Nat64Args -> Command
mkWatchTaskCmd a            = CmdWatchTask (MkNat64Id a.id)

private mkChangeTaskStatusCmd : ChangeTaskStatusArgs -> Command
mkChangeTaskStatusCmd a     = CmdChangeTaskStatus (MkNat64Id a.id) a.status (MkVersion a.version)

private mkTaskCommentCmd    : TaskCommentArgs -> Command
mkTaskCommentCmd a          = CmdTaskComment (MkNat64Id a.id) a.text (MkVersion a.version)

private mkCreateIssueCmd    : CreateIssueArgs -> Command
mkCreateIssueCmd a =
  CmdCreateIssue a.project a.subject a.description a.priority a.severity a.type

private mkUpdateIssueCmd    : UpdateIssueArgs -> Command
mkUpdateIssueCmd a =
  CmdUpdateIssue (MkNat64Id a.id) a.subject a.description a.type a.status (MkVersion a.version)

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
mkCreateMilestoneCmd a =
  CmdCreateMilestone a.project a.name (toMaybe a.estimated_start) (toMaybe a.estimated_finish)
  where
    toMaybe : String -> Maybe String
    toMaybe ""      = Nothing
    toMaybe str     = Just str

private mkUpdateMilestoneCmd : UpdateMilestoneArgs -> Command
mkUpdateMilestoneCmd a =
  CmdUpdateMilestone (MkNat64Id a.id) a.name a.estimated_start a.estimated_finish (MkVersion a.version)

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
