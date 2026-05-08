module Command.Types
import Model.Auth
import Model.Common
import JSON.Derive
import JSON.ToJSON
import JSON.FromJSON

%language ElabReflection

public export
record RefreshArgs where
  constructor MkRefreshArgs
  refresh : String
  refreshArgsTag : String

%runElab derive "RefreshArgs" [Show, FromJSON]

public export
record ListProjectsArgs where
  constructor MkListProjectsArgs
  member : Maybe String
  listProjectsTag : String

%runElab derive "ListProjectsArgs" [Show, FromJSON]

public export
record GetProjectArgs where
  constructor MkGetProjectArgs
  id : Maybe Bits64
  slug : Maybe String

%runElab derive "GetProjectArgs" [Show, FromJSON]

public export
record StringArgs where
  constructor MkStringArgs
  project : String
  stringArgsTag : String

%runElab derive "StringArgs" [Show, FromJSON]

public export
record MaybeStringArgs where
  constructor MkMaybeStringArgs
  project : Maybe String
  maybeStringArgsTag : String

%runElab derive "MaybeStringArgs" [Show, FromJSON]

public export
record ListArgs where
  constructor MkListArgs
  project : Maybe String
  page : Maybe Bits32
  pageSize : Maybe Bits32
  status : Maybe String
  assignedTo : Maybe String
  milestone : Maybe String
  listArgsTag : String

%runElab derive "ListArgs" [Show, ToJSON]

public export
implementation FromJSON ListArgs where
  fromJSON =
    withObject "ListArgs" $ (\o => [|MkListArgs (fieldMaybe o "project") (fieldMaybe o "page") (fieldMaybe o "pageSize") (fieldMaybe o "status") (fieldMaybe o "assignedTo") (fieldMaybe o "milestone") (fromMaybe "" <$> fieldMaybe o "listArgsTag")|])

public export
record MaybeNat64Args where
  constructor MkMaybeNat64Args
  id : Maybe Bits64
  maybeNat64ArgsTag : String

%runElab derive "MaybeNat64Args" [Show, FromJSON]

public export
record Nat64Args where
  constructor MkNat64Args
  id : Bits64
  nat64ArgsTag : String

%runElab derive "Nat64Args" [Show, FromJSON]

public export
record SearchArgs where
  constructor MkSearchArgs
  project : String
  text : String

%runElab derive "SearchArgs" [Show, FromJSON]

public export
record ResolveArgs where
  constructor MkResolveArgs
  project : String
  ref : String

%runElab derive "ResolveArgs" [Show, FromJSON]

public export
record CreateEpicArgs where
  constructor MkCreateEpicArgs
  project : String
  subject : String
  description : Maybe String
  status : Maybe String

%runElab derive "CreateEpicArgs" [Show, FromJSON]

public export
record UpdateEpicArgs where
  constructor MkUpdateEpicArgs
  id : Bits64
  subject : Maybe String
  description : Maybe String
  status : Maybe String
  version : Bits32

%runElab derive "UpdateEpicArgs" [Show, FromJSON]

public export
record CreateStoryArgs where
  constructor MkCreateStoryArgs
  project : String
  subject : String
  description : Maybe String
  milestone : Maybe Bits64

%runElab derive "CreateStoryArgs" [Show, FromJSON]

public export
record UpdateStoryArgs where
  constructor MkUpdateStoryArgs
  id : Bits64
  subject : Maybe String
  description : Maybe String
  milestone : Maybe String
  version : Bits32

%runElab derive "UpdateStoryArgs" [Show, FromJSON]

public export
record CreateTaskArgs where
  constructor MkCreateTaskArgs
  project : String
  subject : String
  story : Maybe Bits64
  description : Maybe String
  status : Maybe String
  milestone : Maybe Bits64

%runElab derive "CreateTaskArgs" [Show, FromJSON]

public export
record UpdateTaskArgs where
  constructor MkUpdateTaskArgs
  id : Bits64
  subject : Maybe String
  description : Maybe String
  status : Maybe String
  version : Bits32

%runElab derive "UpdateTaskArgs" [Show, FromJSON]

public export
record ChangeTaskStatusArgs where
  constructor MkChangeTaskStatusArgs
  id : Bits64
  status : Bits64
  version : Bits32

%runElab derive "ChangeTaskStatusArgs" [Show, FromJSON]

public export
record TaskCommentArgs where
  constructor MkTaskCommentArgs
  id : Bits64
  text : String
  version : Bits32

%runElab derive "TaskCommentArgs" [Show, FromJSON]

public export
record CreateIssueArgs where
  constructor MkCreateIssueArgs
  project : String
  subject : String
  description : Maybe String
  priority : Maybe String
  severity : Maybe String
  type : Maybe String

%runElab derive "CreateIssueArgs" [Show, FromJSON]

public export
record UpdateIssueArgs where
  constructor MkUpdateIssueArgs
  id : Bits64
  subject : Maybe String
  description : Maybe String
  type : Maybe String
  status : Maybe String
  version : Bits32

%runElab derive "UpdateIssueArgs" [Show, FromJSON]

public export
record CreateWikiArgs where
  constructor MkCreateWikiArgs
  project : String
  slug : String
  content : String

%runElab derive "CreateWikiArgs" [Show, FromJSON]

public export
record UpdateWikiArgs where
  constructor MkUpdateWikiArgs
  id : Bits64
  content : Maybe String
  slug : Maybe String
  version : Bits32

%runElab derive "UpdateWikiArgs" [Show, FromJSON]

public export
record EntityIdArgs where
  constructor MkEntityIdArgs
  entity : String
  id : Bits64

%runElab derive "EntityIdArgs" [Show, FromJSON]

public export
record CommentArgs where
  constructor MkCommentArgs
  entity : String
  id : Bits64
  text : String

%runElab derive "CommentArgs" [Show, FromJSON]

public export
record CreateMilestoneArgs where
  constructor MkCreateMilestoneArgs
  project : String
  name : String
  estimated_start : String
  estimated_finish : String

%runElab derive "CreateMilestoneArgs" [Show, FromJSON]

public export
record UpdateMilestoneArgs where
  constructor MkUpdateMilestoneArgs
  id : Bits64
  name : Maybe String
  estimated_start : Maybe String
  estimated_finish : Maybe String
  version : Bits32

%runElab derive "UpdateMilestoneArgs" [Show, FromJSON]

public export
data Command : Type where
  CmdPing : Command
  CmdLogin : Credentials -> Command
  CmdRefresh : String -> Command
  CmdMe : Command
  CmdListProjects : Maybe String -> Command
  CmdGetProject : Maybe Nat64Id -> Maybe Slug -> Command
  CmdListEpics : ListArgs -> Command
  CmdGetEpic : Maybe Nat64Id -> Command
  CmdListStories : ListArgs -> Command
  CmdGetStory : Maybe Nat64Id -> Command
  CmdListTasks : ListArgs -> Command
  CmdGetTask : Maybe Nat64Id -> Command
  CmdListIssues : ListArgs -> Command
  CmdGetIssue : Maybe Nat64Id -> Command
  CmdListWiki : ListArgs -> Command
  CmdGetWiki : Maybe Nat64Id -> Command
  CmdListMilestones : ListArgs -> Command
  CmdListUsers : String -> Command
  CmdListMemberships : String -> Command
  CmdListRoles : String -> Command
  CmdSearch : String -> String -> Command
  CmdResolve : String -> String -> Command
  CmdCreateEpic : String -> String -> Maybe String -> Maybe String -> Command
  CmdUpdateEpic : Nat64Id -> Maybe String -> Maybe String -> Maybe String -> Version -> Command
  CmdDeleteEpic : Nat64Id -> Command
  CmdCreateStory : String -> String -> Maybe String -> Maybe Nat64Id -> Command
  CmdUpdateStory : Nat64Id -> Maybe String -> Maybe String -> Maybe String -> Version -> Command
  CmdDeleteStory : Nat64Id -> Command
  CmdCreateTask : String -> String -> Maybe Nat64Id -> Maybe String -> Maybe String -> Maybe Bits64 -> Command
  CmdUpdateTask : Nat64Id -> Maybe String -> Maybe String -> Maybe String -> Version -> Command
  CmdDeleteTask : Nat64Id -> Command
  CmdWatchTask : Nat64Id -> Command
  CmdChangeTaskStatus : Nat64Id -> Bits64 -> Version -> Command
  CmdTaskComment : Nat64Id -> String -> Version -> Command
  CmdCreateIssue : String -> String -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> Command
  CmdUpdateIssue : Nat64Id -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> Version -> Command
  CmdDeleteIssue : Nat64Id -> Command
  CmdCreateWiki : String -> String -> String -> Command
  CmdUpdateWiki : Nat64Id -> Maybe String -> Maybe String -> Version -> Command
  CmdDeleteWiki : Nat64Id -> Command
  CmdComment : String -> Nat64Id -> String -> Command
  CmdListComments : String -> Nat64Id -> Command
  CmdCreateMilestone : String -> String -> Maybe String -> Maybe String -> Command
  CmdUpdateMilestone : Nat64Id -> Maybe String -> Maybe String -> Maybe String -> Version -> Command
  CmdDeleteMilestone : Nat64Id -> Command
-- Health check (no auth needed)
%runElab derive "Command" [Show, ToJSON, FromJSON]
