module Command.Parse
import Command.Types
import Model.Auth
import Model.Common
import JSON.FromJSON
import Data.Either
import Data.String

%language ElabReflection

parseCmdArgs : FromJSON a => (a -> Command) -> String -> Either String Command
parseCmdArgs fn =
  map fn . decodeEither

mkRefreshCmd : RefreshArgs -> Command
mkRefreshCmd r =
  CmdRefresh r.refresh

mkListProjectsCmd : ListProjectsArgs -> Command
mkListProjectsCmd a =
  CmdListProjects a.member

mkGetProjectCmd : GetProjectArgs -> Command
mkGetProjectCmd a =
  CmdGetProject (map MkNat64Id a.id) (map MkSlug a.slug)

mkListEpicsCmd : ListArgs -> Command
mkListEpicsCmd a =
  CmdListEpics a

mkGetEpicCmd : MaybeNat64Args -> Command
mkGetEpicCmd a =
  CmdGetEpic (map MkNat64Id a.id)

mkListStoriesCmd : ListArgs -> Command
mkListStoriesCmd a =
  CmdListStories a

mkGetStoryCmd : MaybeNat64Args -> Command
mkGetStoryCmd a =
  CmdGetStory (map MkNat64Id a.id)

mkListTasksCmd : ListArgs -> Command
mkListTasksCmd a =
  CmdListTasks a

mkGetTaskCmd : MaybeNat64Args -> Command
mkGetTaskCmd a =
  CmdGetTask (map MkNat64Id a.id)

mkListIssuesCmd : ListArgs -> Command
mkListIssuesCmd a =
  CmdListIssues a

mkGetIssueCmd : MaybeNat64Args -> Command
mkGetIssueCmd a =
  CmdGetIssue (map MkNat64Id a.id)

mkListWikiCmd : ListArgs -> Command
mkListWikiCmd a =
  CmdListWiki a

mkGetWikiCmd : MaybeNat64Args -> Command
mkGetWikiCmd a =
  CmdGetWiki (map MkNat64Id a.id)

mkListMilestonesCmd : ListArgs -> Command
mkListMilestonesCmd a =
  CmdListMilestones a

mkListUsersCmd : StringArgs -> Command
mkListUsersCmd a =
  CmdListUsers a.project

mkListMembershipsCmd : StringArgs -> Command
mkListMembershipsCmd a =
  CmdListMemberships a.project

mkListRolesCmd : StringArgs -> Command
mkListRolesCmd a =
  CmdListRoles a.project

mkSearchCmd : SearchArgs -> Command
mkSearchCmd a =
  CmdSearch a.project a.text

mkResolveCmd : ResolveArgs -> Command
mkResolveCmd a =
  CmdResolve a.project a.ref

mkCreateEpicCmd : CreateEpicArgs -> Command
mkCreateEpicCmd a =
  CmdCreateEpic a.project a.subject a.description a.status

mkUpdateEpicCmd : UpdateEpicArgs -> Command
mkUpdateEpicCmd a =
  CmdUpdateEpic (MkNat64Id a.id) a.subject a.description a.status (MkVersion a.version)

mkDeleteEpicCmd : Nat64Args -> Command
mkDeleteEpicCmd a =
  CmdDeleteEpic (MkNat64Id a.id)

mkCreateStoryCmd : CreateStoryArgs -> Command
mkCreateStoryCmd a =
  CmdCreateStory a.project a.subject a.description (map MkNat64Id a.milestone)

mkUpdateStoryCmd : UpdateStoryArgs -> Command
mkUpdateStoryCmd a =
  CmdUpdateStory (MkNat64Id a.id) a.subject a.description a.milestone (MkVersion a.version)

mkDeleteStoryCmd : Nat64Args -> Command
mkDeleteStoryCmd a =
  CmdDeleteStory (MkNat64Id a.id)

mkCreateTaskCmd : CreateTaskArgs -> Command
mkCreateTaskCmd a =
  CmdCreateTask a.project a.subject (map MkNat64Id a.story) a.description a.status a.milestone

mkUpdateTaskCmd : UpdateTaskArgs -> Command
mkUpdateTaskCmd a =
  CmdUpdateTask (MkNat64Id a.id) a.subject a.description a.status (MkVersion a.version)

mkDeleteTaskCmd : Nat64Args -> Command
mkDeleteTaskCmd a =
  CmdDeleteTask (MkNat64Id a.id)

mkWatchTaskCmd : Nat64Args -> Command
mkWatchTaskCmd a =
  CmdWatchTask (MkNat64Id a.id)

mkChangeTaskStatusCmd : ChangeTaskStatusArgs -> Command
mkChangeTaskStatusCmd a =
  CmdChangeTaskStatus (MkNat64Id a.id) a.status (MkVersion a.version)

mkTaskCommentCmd : TaskCommentArgs -> Command
mkTaskCommentCmd a =
  CmdTaskComment (MkNat64Id a.id) a.text (MkVersion a.version)

mkCreateIssueCmd : CreateIssueArgs -> Command
mkCreateIssueCmd a =
  CmdCreateIssue a.project a.subject a.description a.priority a.severity a.type

mkUpdateIssueCmd : UpdateIssueArgs -> Command
mkUpdateIssueCmd a =
  CmdUpdateIssue (MkNat64Id a.id) a.subject a.description a.type a.status (MkVersion a.version)

mkDeleteIssueCmd : Nat64Args -> Command
mkDeleteIssueCmd a =
  CmdDeleteIssue (MkNat64Id a.id)

mkCreateWikiCmd : CreateWikiArgs -> Command
mkCreateWikiCmd a =
  CmdCreateWiki a.project a.slug a.content

mkUpdateWikiCmd : UpdateWikiArgs -> Command
mkUpdateWikiCmd a =
  CmdUpdateWiki (MkNat64Id a.id) a.content a.slug (MkVersion a.version)

mkDeleteWikiCmd : Nat64Args -> Command
mkDeleteWikiCmd a =
  CmdDeleteWiki (MkNat64Id a.id)

mkCommentCmd : CommentArgs -> Command
mkCommentCmd a =
  CmdComment a.entity (MkNat64Id a.id) a.text

mkListCommentsCmd : EntityIdArgs -> Command
mkListCommentsCmd a =
  CmdListComments a.entity (MkNat64Id a.id)

mkCreateMilestoneCmd : CreateMilestoneArgs -> Command
mkCreateMilestoneCmd a =
  CmdCreateMilestone a.project a.name (toMaybe a.estimated_start) (toMaybe a.estimated_finish)
  where
    toMaybe : String -> Maybe String
    toMaybe "" =
      Nothing
    toMaybe str =
      Just str

mkUpdateMilestoneCmd : UpdateMilestoneArgs -> Command
mkUpdateMilestoneCmd a =
  CmdUpdateMilestone (MkNat64Id a.id) a.name a.estimated_start a.estimated_finish (MkVersion a.version)

mkDeleteMilestoneCmd : Nat64Args -> Command
mkDeleteMilestoneCmd a =
  CmdDeleteMilestone (MkNat64Id a.id)

public export
parseCommand : (cmd : String) -> (args : String) -> Either String Command
parseCommand "ping" _ =
  pure CmdPing
parseCommand "me" _ =
  pure CmdMe
parseCommand "login" args =
  parseCmdArgs CmdLogin args
parseCommand "refresh" args =
  parseCmdArgs mkRefreshCmd args
parseCommand "list-projects" args =
  parseCmdArgs mkListProjectsCmd args
parseCommand "get-project" args =
  parseCmdArgs mkGetProjectCmd args
parseCommand "list-epics" args =
  parseCmdArgs mkListEpicsCmd args
parseCommand "get-epic" args =
  parseCmdArgs mkGetEpicCmd args
parseCommand "list-stories" args =
  parseCmdArgs mkListStoriesCmd args
parseCommand "get-story" args =
  parseCmdArgs mkGetStoryCmd args
parseCommand "list-tasks" args =
  parseCmdArgs mkListTasksCmd args
parseCommand "get-task" args =
  parseCmdArgs mkGetTaskCmd args
parseCommand "list-issues" args =
  parseCmdArgs mkListIssuesCmd args
parseCommand "get-issue" args =
  parseCmdArgs mkGetIssueCmd args
parseCommand "list-wiki" args =
  parseCmdArgs mkListWikiCmd args
parseCommand "get-wiki" args =
  parseCmdArgs mkGetWikiCmd args
parseCommand "list-milestones" args =
  parseCmdArgs mkListMilestonesCmd args
parseCommand "list-users" args =
  parseCmdArgs mkListUsersCmd args
parseCommand "list-memberships" args =
  parseCmdArgs mkListMembershipsCmd args
parseCommand "list-roles" args =
  parseCmdArgs mkListRolesCmd args
parseCommand "search" args =
  parseCmdArgs mkSearchCmd args
parseCommand "resolve" args =
  parseCmdArgs mkResolveCmd args
parseCommand "create-epic" args =
  parseCmdArgs mkCreateEpicCmd args
parseCommand "update-epic" args =
  parseCmdArgs mkUpdateEpicCmd args
parseCommand "delete-epic" args =
  parseCmdArgs mkDeleteEpicCmd args
parseCommand "create-story" args =
  parseCmdArgs mkCreateStoryCmd args
parseCommand "update-story" args =
  parseCmdArgs mkUpdateStoryCmd args
parseCommand "delete-story" args =
  parseCmdArgs mkDeleteStoryCmd args
parseCommand "create-task" args =
  parseCmdArgs mkCreateTaskCmd args
parseCommand "update-task" args =
  parseCmdArgs mkUpdateTaskCmd args
parseCommand "delete-task" args =
  parseCmdArgs mkDeleteTaskCmd args
parseCommand "watch-task" args =
  parseCmdArgs mkWatchTaskCmd args
parseCommand "change-task-status" args =
  parseCmdArgs mkChangeTaskStatusCmd args
parseCommand "task-comment" args =
  parseCmdArgs mkTaskCommentCmd args
parseCommand "create-issue" args =
  parseCmdArgs mkCreateIssueCmd args
parseCommand "update-issue" args =
  parseCmdArgs mkUpdateIssueCmd args
parseCommand "delete-issue" args =
  parseCmdArgs mkDeleteIssueCmd args
parseCommand "create-wiki" args =
  parseCmdArgs mkCreateWikiCmd args
parseCommand "update-wiki" args =
  parseCmdArgs mkUpdateWikiCmd args
parseCommand "delete-wiki" args =
  parseCmdArgs mkDeleteWikiCmd args
parseCommand "comment" args =
  parseCmdArgs mkCommentCmd args
parseCommand "list-comments" args =
  parseCmdArgs mkListCommentsCmd args
parseCommand "create-milestone" args =
  parseCmdArgs mkCreateMilestoneCmd args
parseCommand "update-milestone" args =
  parseCmdArgs mkUpdateMilestoneCmd args
parseCommand "delete-milestone" args =
  parseCmdArgs mkDeleteMilestoneCmd args
parseCommand cmd _ =
  Left $ "Unknown command: " ++ cmd
