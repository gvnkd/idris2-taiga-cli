||| Argument records and Command sum type for agent-mode operations.
|||
||| Each argument record corresponds to one agent-visible operation,
||| carrying the fields needed to parse JSON arguments from stdin.
||| The `Command` sum type is the internal representation after parsing.
module Command.Types

import Model.Auth
import Model.Common
import JSON.Derive
import JSON.ToJSON
import JSON.FromJSON

%language ElabReflection

||| Refresh token argument wrapper.
public export
record RefreshArgs where
  constructor MkRefreshArgs
  refresh : String
  refreshArgsTag : String

%runElab derive "RefreshArgs" [Show,FromJSON]

||| --- Argument records for agent-mode command parsing ---

||| Arguments for listing projects.
public export
record ListProjectsArgs where
  constructor MkListProjectsArgs
  member : Maybe String
  listProjectsTag : String

%runElab derive "ListProjectsArgs" [Show,FromJSON]

||| Arguments for fetching a project by ID or slug.
public export
record GetProjectArgs where
  constructor MkGetProjectArgs
  id : Maybe Bits64
  slug : Maybe String

%runElab derive "GetProjectArgs" [Show,FromJSON]

||| Simple wrapper holding a single required project string.
public export
record StringArgs where
  constructor MkStringArgs
  project : String
  stringArgsTag : String

%runElab derive "StringArgs" [Show,FromJSON]

||| Simple wrapper holding an optional project string.
public export
record MaybeStringArgs where
  constructor MkMaybeStringArgs
  project : Maybe String
  maybeStringArgsTag : String

%runElab derive "MaybeStringArgs" [Show,FromJSON]

||| Arguments for list commands with pagination and filters.
public export
record ListArgs where
  constructor MkListArgs
  project     : Maybe String
  page        : Maybe Bits32
  pageSize    : Maybe Bits32
  status      : Maybe String
  assignedTo  : Maybe String
  milestone   : Maybe String
  listArgsTag : String

%runElab derive "ListArgs" [Show,ToJSON]

||| Custom FromJSON: backward-compatible with old StringArgs format
||| and lenient with missing pagination/filter fields.
public export
FromJSON ListArgs where
  fromJSON =
    withObject "ListArgs" $ \o =>
      [| MkListArgs
           (fieldMaybe o "project")
           (fieldMaybe o "page")
           (fieldMaybe o "pageSize")
           (fieldMaybe o "status")
           (fieldMaybe o "assignedTo")
           (fieldMaybe o "milestone")
           (fromMaybe "" <$> fieldMaybe o "listArgsTag")
       |]

||| Simple wrapper holding an optional entity ID.
public export
record MaybeNat64Args where
  constructor MkMaybeNat64Args
  id : Maybe Bits64
  maybeNat64ArgsTag : String

%runElab derive "MaybeNat64Args" [Show,FromJSON]

||| Simple wrapper holding a required entity ID.
public export
record Nat64Args where
  constructor MkNat64Args
  id : Bits64
  nat64ArgsTag : String

%runElab derive "Nat64Args" [Show,FromJSON]

||| Arguments for project-wide text search.
public export
record SearchArgs where
  constructor MkSearchArgs
  project : String
  text : String

%runElab derive "SearchArgs" [Show,FromJSON]

||| Arguments for resolving an entity ref to its ID.
public export
record ResolveArgs where
  constructor MkResolveArgs
  project : String
  ref : String

%runElab derive "ResolveArgs" [Show,FromJSON]

||| Arguments for creating a new epic.
public export
record CreateEpicArgs where
  constructor MkCreateEpicArgs
  project : String
  subject : String
  description : Maybe String
  status : Maybe String

%runElab derive "CreateEpicArgs" [Show,FromJSON]

||| Arguments for updating an existing epic.
public export
record UpdateEpicArgs where
  constructor MkUpdateEpicArgs
  id : Bits64
  subject : Maybe String
  description : Maybe String
  status : Maybe String
  version : Bits32

%runElab derive "UpdateEpicArgs" [Show,FromJSON]

||| Arguments for creating a new user story.
public export
record CreateStoryArgs where
  constructor MkCreateStoryArgs
  project : String
  subject : String
  description : Maybe String
  milestone : Maybe Bits64

%runElab derive "CreateStoryArgs" [Show,FromJSON]

||| Arguments for updating an existing user story.
public export
record UpdateStoryArgs where
  constructor MkUpdateStoryArgs
  id : Bits64
  subject : Maybe String
  description : Maybe String
  milestone : Maybe String
  version : Bits32

%runElab derive "UpdateStoryArgs" [Show,FromJSON]

||| Arguments for creating a new task.
public export
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
public export
record UpdateTaskArgs where
  constructor MkUpdateTaskArgs
  id : Bits64
  subject : Maybe String
  description : Maybe String
  status : Maybe String
  version : Bits32

%runElab derive "UpdateTaskArgs" [Show,FromJSON]

||| Arguments for changing a task's status.
public export
record ChangeTaskStatusArgs where
  constructor MkChangeTaskStatusArgs
  id : Bits64
  status : Bits64
  version : Bits32

%runElab derive "ChangeTaskStatusArgs" [Show,FromJSON]

||| Arguments for adding a comment to a task.
public export
record TaskCommentArgs where
  constructor MkTaskCommentArgs
  id : Bits64
  text : String
  version : Bits32

%runElab derive "TaskCommentArgs" [Show,FromJSON]

||| Arguments for creating a new issue.
public export
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
public export
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
public export
record CreateWikiArgs where
  constructor MkCreateWikiArgs
  project : String
  slug : String
  content : String

%runElab derive "CreateWikiArgs" [Show,FromJSON]

||| Arguments for updating an existing wiki page.
public export
record UpdateWikiArgs where
  constructor MkUpdateWikiArgs
  id : Bits64
  content : Maybe String
  slug : Maybe String
  version : Bits32

%runElab derive "UpdateWikiArgs" [Show,FromJSON]

||| Arguments identifying a generic entity by type and ID.
public export
record EntityIdArgs where
  constructor MkEntityIdArgs
  entity : String
  id : Bits64

%runElab derive "EntityIdArgs" [Show,FromJSON]

||| Arguments for adding a comment to any entity.
public export
record CommentArgs where
  constructor MkCommentArgs
  entity : String
  id : Bits64
  text : String

%runElab derive "CommentArgs" [Show,FromJSON]

||| Arguments for creating a new milestone.
public export
record CreateMilestoneArgs where
  constructor MkCreateMilestoneArgs
  project : String
  name : String
  estimated_start : String
  estimated_finish : String

%runElab derive "CreateMilestoneArgs" [Show,FromJSON]

||| Arguments for updating an existing milestone.
public export
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
  CmdListEpics        : ListArgs -> Command
  CmdGetEpic          : Maybe Nat64Id -> Command
  CmdListStories      : ListArgs -> Command
  CmdGetStory         : Maybe Nat64Id -> Command
  CmdListTasks        : ListArgs -> Command
  CmdGetTask          : Maybe Nat64Id -> Command
  CmdListIssues       : ListArgs -> Command
  CmdGetIssue         : Maybe Nat64Id -> Command
  CmdListWiki         : ListArgs -> Command
  CmdGetWiki          : Maybe Nat64Id -> Command
  CmdListMilestones   : ListArgs -> Command
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
  CmdCreateTask :
       String
    -> String
    -> Maybe Nat64Id
    -> Maybe String
    -> Maybe String
    -> Maybe Bits64
    -> Command
  CmdUpdateTask     : Nat64Id -> Maybe String -> Maybe String -> Maybe String -> Version -> Command
  CmdDeleteTask     : Nat64Id -> Command
  CmdWatchTask      : Nat64Id -> Command
  CmdChangeTaskStatus : Nat64Id -> Bits64 -> Version -> Command
  CmdTaskComment    : Nat64Id -> String -> Version -> Command

  -- Write / mutation commands — issues
  CmdCreateIssue :
       String
    -> String
    -> Maybe String
    -> Maybe String
    -> Maybe String
    -> Maybe String
    -> Command
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
