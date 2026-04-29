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
import JSON.Derive
import Protocol.Request
import Protocol.Response

%language ElabReflection

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
  CmdCreateTask : String -> String -> Maybe Nat64Id -> Maybe String -> Maybe String -> Command
  CmdUpdateTask : Nat64Id -> Maybe String -> Maybe String -> Maybe String -> Version -> Command
  CmdDeleteTask : Nat64Id -> Command

  -- Write / mutation commands — issues
  CmdCreateIssue : String -> String -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> Command
  CmdUpdateIssue : Nat64Id -> Maybe String -> Maybe String -> Maybe String -> Version -> Command
  CmdDeleteIssue : Nat64Id -> Command

  -- Write / mutation commands — wiki
  CmdCreateWiki : String -> String -> String -> Command
  CmdUpdateWiki : Nat64Id -> Maybe String -> Maybe String -> Version -> Command
  CmdDeleteWiki : Nat64Id -> Command

  -- Comments (via history API)
  CmdComment      : String -> Nat64Id -> String -> Command
  CmdEditComment  : String -> Nat64Id -> Nat64Id -> String -> Command
  CmdDeleteComment : String -> Nat64Id -> Nat64Id -> Command

  -- Milestones
  CmdCreateMilestone : String -> String -> String -> String -> Command
  CmdUpdateMilestone : Nat64Id -> Maybe String -> Maybe String -> Maybe String -> Version -> Command

%runElab derive "Command" [Show,ToJSON,FromJSON]

||| Dispatch a parsed Command together with auth and base URL,
||| returning a Response.
dispatchCommand :
     HasIO io =>
     (command : Command)
  -> (auth  : Maybe Model.Auth.Token)
  -> (base  : Maybe String)
  -> io Response
dispatchCommand = ?rhs_dispatchCommand
