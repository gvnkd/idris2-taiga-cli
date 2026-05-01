||| CLI argument types.
|||
||| Mirrors the Command sum type but tailored for human-readable
||| command-line flags.  Each constructor corresponds to one
||| invocation of the binary (e.g. `taiga-cli --list-epics myproject`).
module CLI.Args

import Model.Auth
import Model.Common
import Command

||| Parsed CLI flags — one variant per sub-command or flag group.
public export
data CLIArgs : Type where
  -- Help and meta
  ArgHelp   : CLIArgs
  ArgVersion : CLIArgs
  ArgStdin   : CLIArgs

  -- Global options (always available)
  ArgBase     : String -> CLIArgs

  -- Authentication
  ArgLogin    : (username : String) -> (password : String) -> CLIArgs
  ArgMe       : CLIArgs

  -- Read-only / list
  ArgListProjects     : Maybe String -> CLIArgs
  ArgGetProject       : Maybe Nat64Id -> Maybe Slug -> CLIArgs
  ArgListEpics        : String -> CLIArgs
  ArgGetEpic          : Maybe Nat64Id -> CLIArgs
  ArgListStories      : String -> CLIArgs
  ArgGetStory         : Maybe Nat64Id -> CLIArgs
  ArgListTasks        : Maybe String -> CLIArgs
  ArgGetTask          : Maybe Nat64Id -> CLIArgs
  ArgListIssues       : String -> CLIArgs
  ArgGetIssue         : Maybe Nat64Id -> CLIArgs
  ArgListWiki         : String -> CLIArgs
  ArgGetWiki          : Maybe Nat64Id -> CLIArgs
  ArgListMilestones   : String -> CLIArgs
  ArgListUsers        : String -> CLIArgs
  ArgListMemberships  : String -> CLIArgs
  ArgListRoles        : String -> CLIArgs
  ArgSearch           : String -> String -> CLIArgs
  ArgResolve          : String -> String -> CLIArgs

  -- Epics
  ArgCreateEpic   : String -> String -> Maybe String -> Maybe String -> CLIArgs
  ArgUpdateEpic   : Nat64Id -> Maybe String -> Maybe String -> Maybe String -> Version -> CLIArgs
  ArgDeleteEpic   : Nat64Id -> CLIArgs

  -- Stories
  ArgCreateStory  : String -> String -> Maybe String -> Maybe Nat64Id -> CLIArgs
  ArgUpdateStory  : Nat64Id -> Maybe String -> Maybe String -> Maybe String -> Version -> CLIArgs
  ArgDeleteStory  : Nat64Id -> CLIArgs

  -- Tasks
  ArgCreateTask   : String -> String -> Maybe Nat64Id -> Maybe String -> Maybe String -> Maybe Bits64 -> CLIArgs
  ArgUpdateTask   : Nat64Id -> Maybe String -> Maybe String -> Maybe String -> Version -> CLIArgs
  ArgDeleteTask   : Nat64Id -> CLIArgs

  -- Issues
  ArgCreateIssue  : String -> String -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> CLIArgs
  ArgUpdateIssue  : Nat64Id -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> Version -> CLIArgs
  ArgDeleteIssue  : Nat64Id -> CLIArgs

  -- Wiki
  ArgCreateWiki   : String -> String -> String -> CLIArgs
  ArgUpdateWiki   : Nat64Id -> Maybe String -> Maybe String -> Version -> CLIArgs
  ArgDeleteWiki   : Nat64Id -> CLIArgs

  -- Comments / history
  ArgComment       : String -> Nat64Id -> String -> CLIArgs
   ArgListComments  : String -> Nat64Id -> CLIArgs

  -- Task management
  ArgWatchTask     : Nat64Id -> CLIArgs
  ArgChangeTaskStatus : Nat64Id -> Bits64 -> Version -> CLIArgs
  ArgTaskComment   : Nat64Id -> String -> Version -> CLIArgs

  -- Milestones
  ArgCreateMilestone   : String -> String -> Maybe String -> Maybe String -> CLIArgs
  ArgUpdateMilestone   : Nat64Id -> Maybe String -> Maybe String -> Maybe String -> Version -> CLIArgs
  ArgDeleteMilestone   : Nat64Id -> CLIArgs

||| Convert parsed CLI args into the unified Command type.
||| Authentication and base URL are resolved separately by the caller.
public export
toCommand : CLIArgs -> Command
toCommand ArgHelp                    = CmdMe
toCommand ArgVersion                = CmdMe
toCommand ArgStdin                 = CmdMe
toCommand (ArgBase _)              = CmdMe
toCommand (ArgLogin u p)           = CmdLogin $ MkCredentials u p
toCommand ArgMe                    = CmdMe
toCommand (ArgListProjects m)      = CmdListProjects m
toCommand (ArgGetProject mid ms)   = CmdGetProject mid ms
toCommand (ArgListEpics p)         = CmdListEpics p
toCommand (ArgGetEpic mid)         = CmdGetEpic mid
toCommand (ArgListStories p)       = CmdListStories p
toCommand (ArgGetStory mid)        = CmdGetStory mid
toCommand (ArgListTasks p)         = CmdListTasks p
toCommand (ArgGetTask mid)         = CmdGetTask mid
toCommand (ArgListIssues p)        = CmdListIssues p
toCommand (ArgGetIssue mid)        = CmdGetIssue mid
toCommand (ArgListWiki p)          = CmdListWiki p
toCommand (ArgGetWiki mid)         = CmdGetWiki mid
toCommand (ArgListMilestones p)    = CmdListMilestones p
toCommand (ArgListUsers p)         = CmdListUsers p
toCommand (ArgListMemberships p)   = CmdListMemberships p
toCommand (ArgListRoles p)         = CmdListRoles p
toCommand (ArgSearch p t)          = CmdSearch p t
toCommand (ArgResolve p r)         = CmdResolve p r
toCommand (ArgCreateEpic p s d st) = CmdCreateEpic p s d st
toCommand (ArgUpdateEpic id s d st v) = CmdUpdateEpic id s d st v
toCommand (ArgDeleteEpic id)       = CmdDeleteEpic id
toCommand (ArgCreateStory p s d m) = CmdCreateStory p s d m
toCommand (ArgUpdateStory id s d m v) = CmdUpdateStory id s d m v
toCommand (ArgDeleteStory id)      = CmdDeleteStory id
toCommand (ArgCreateTask p s st d st2 ms) = CmdCreateTask p s st d st2 ms
toCommand (ArgUpdateTask id s d st v) = CmdUpdateTask id s d st v
toCommand (ArgDeleteTask id)       = CmdDeleteTask id
toCommand (ArgCreateIssue p s d pr sv it) = CmdCreateIssue p s d pr sv it
toCommand (ArgUpdateIssue id s d it st v) = CmdUpdateIssue id s d it st v
toCommand (ArgDeleteIssue id)      = CmdDeleteIssue id
toCommand (ArgCreateWiki p sl c)  = CmdCreateWiki p sl c
toCommand (ArgUpdateWiki id c sl v) = CmdUpdateWiki id c sl v
toCommand (ArgDeleteWiki id)       = CmdDeleteWiki id
toCommand (ArgComment e id t)      = CmdComment e id t
toCommand (ArgListComments e id)   = CmdListComments e id
toCommand (ArgWatchTask id)        = CmdWatchTask id
toCommand (ArgChangeTaskStatus id st v) = CmdChangeTaskStatus id st v
toCommand (ArgTaskComment id t v)  = CmdTaskComment id t v
toCommand (ArgCreateMilestone p n es ef) = CmdCreateMilestone p n es ef
toCommand (ArgUpdateMilestone id n es ef v) = CmdUpdateMilestone id n es ef v
toCommand (ArgDeleteMilestone id) = CmdDeleteMilestone id
