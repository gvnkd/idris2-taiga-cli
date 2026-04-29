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
  ArgCreateTask   : String -> String -> Maybe Nat64Id -> Maybe String -> Maybe String -> CLIArgs
  ArgUpdateTask   : Nat64Id -> Maybe String -> Maybe String -> Maybe String -> Version -> CLIArgs
  ArgDeleteTask   : Nat64Id -> CLIArgs

  -- Issues
  ArgCreateIssue  : String -> String -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> CLIArgs
  ArgUpdateIssue  : Nat64Id -> Maybe String -> Maybe String -> Maybe String -> Version -> CLIArgs
  ArgDeleteIssue  : Nat64Id -> CLIArgs

  -- Wiki
  ArgCreateWiki   : String -> String -> String -> CLIArgs
  ArgUpdateWiki   : Nat64Id -> Maybe String -> Maybe String -> Version -> CLIArgs
  ArgDeleteWiki   : Nat64Id -> CLIArgs

  -- Comments
  ArgComment       : String -> Nat64Id -> String -> CLIArgs
  ArgEditComment   : String -> Nat64Id -> Nat64Id -> String -> CLIArgs
  ArgDeleteComment : String -> Nat64Id -> Nat64Id -> CLIArgs

  -- Milestones
  ArgCreateMilestone   : String -> String -> String -> String -> CLIArgs
  ArgUpdateMilestone   : Nat64Id -> Maybe String -> Maybe String -> Maybe String -> Version -> CLIArgs

||| Convert parsed CLI args into the unified Command type.
||| Authentication and base URL are resolved separately by the caller.
public export
toCommand : CLIArgs -> Command
