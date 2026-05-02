||| Usage help text.
|||
||| Generates the `--help` / `-h` output describing all supported
||| flags and sub-commands.
module CLI.Help

import CLI.Args
import Data.String

||| Print the full usage message to stdout.
public export
usage : String
usage = unlines
  [ "Usage: taiga-cli [OPTIONS] COMMAND"
  , ""
  , "Options:"
  , "  -h, --help          Show this help message"
  , "  --base URL         Taiga API base URL (e.g. http://127.0.0.1:8000/api/v1)"
  , "  --token TOKEN      Bearer token for authenticated commands"
  , "  --stdin            Read JSON command from stdin (agent mode)"
  , ""
  , "Core:"
  , "  init [URL]                    Create state directory and default config"
  , "  login --user U [--password P] Authenticate, persist token"
  , "  logout                        Clear persisted token"
  , "  show                          Display current state (project, auth status)"
  , ""
  , "Project context:"
  , "  project list                  List accessible projects"
  , "  project set <slug|id>         Switch active project"
  , "  project get                   Show active project details"
  , ""
  , "Task operations:"
  , "  task list [--status S]        List tasks in active project"
  , "  task create <subject>         Create task"
  , "  task get <id|ref>             Get task by ID or RefID"
  , "  task status <id|ref> <status> Change task status"
  , "  task comment <id|ref> <text>  Comment on a task"
  , ""
  , "Epic operations:"
  , "  epic list                     List epics in active project"
  , "  epic get <id|ref>             Get epic by ID or RefID"
  , ""
  , "Sprint operations:"
  , "  sprint list                   List all sprints/milestones"
  , "  sprint show                   Show current sprint state"
  , "  sprint set <id|ref>           Set active sprint context"
  , ""
  , "Issue operations:"
  , "  issue list                    List issues in active project"
  , "  issue get <id|ref>            Get issue by ID or RefID"
  , ""
  , "Story operations:"
  , "  story list                    List stories in active project"
  , "  story get <id|ref>            Get story by ID or RefID"
  , ""
  , "Wiki operations:"
  , "  wiki list                     List wiki pages in active project"
  , "  wiki get <id|ref>             Get wiki page by ID or RefID"
  , ""
  , "Global flags:"
  , "  --json                        Output JSON instead of text"
  , "  --base <url>                 Override base URL for this invocation"
  ]

||| Generate a short synopsis (first line of --help).
public export
usageSynopsis : String
usageSynopsis = "taiga-cli [OPTIONS] COMMAND"

||| Generate per-command help text for a single sub-command name.
||| Returns `Nothing` if the name is not recognised.
public export
commandHelp : String -> Maybe String
commandHelp "init"       = Just $ unlines ["init [BASE_URL]", "    Initialize workspace state in ./.taiga/"]
commandHelp "login"      = Just $ unlines ["login --user USERNAME [--password PASSWORD]",
                                          "    Authenticate with Taiga and persist token.",
                                          "    If --password is omitted, the password is read interactively.",
                                          "    WARNING: Passing --password on the command line is insecure."]
commandHelp "logout"     = Just $ unlines ["logout", "    Clear persisted authentication token."]
commandHelp "show"       = Just $ unlines ["show", "    Display current workspace state."]
commandHelp "project"    = Just $ unlines ["project {list|set <slug>|get}", "    Manage active project context."]
commandHelp "task"       = Just $ unlines ["task {list|create|get|status|comment}", "    Manage tasks in active project."]
commandHelp "epic"       = Just $ unlines ["epic {list|get}", "    Manage epics in active project."]
commandHelp "sprint"     = Just $ unlines ["sprint {list|show|set}", "    Manage sprints/milestones."]
commandHelp "issue"      = Just $ unlines ["issue {list|get}", "    Manage issues in active project."]
commandHelp "story"      = Just $ unlines ["story {list|get}", "    Manage stories in active project."]
commandHelp "wiki"       = Just $ unlines ["wiki {list|get}", "    Manage wiki pages in active project."]
commandHelp _            = Nothing

||| List all recognised sub-command / flag names.
public export
knownCommands : List String
knownCommands =
  [ "init"
  , "login"
  , "logout"
  , "show"
  , "project"
  , "task"
  , "epic"
  , "sprint"
  , "issue"
  , "story"
  , "wiki"
  ]
