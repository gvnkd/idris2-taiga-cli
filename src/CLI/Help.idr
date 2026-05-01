||| Usage help text.
|||
||| Generates the `--help` / `-h` output describing all supported
||| flags and sub-commands.
module CLI.Help

import CLI.Args

||| Print the full usage message to stdout.
public export
usage : String
usage =
  "Usage: taiga-cli [OPTIONS] COMMAND\n"
  ++ "\n"
  ++ "Options:\n"
  ++ "  -h, --help          Show this help message\n"
  ++ "  --base URL         Taiga API base URL (e.g. http://127.0.0.1:8000/api/v1)\n"
  ++ "  --token TOKEN      Bearer token for authenticated commands\n"
  ++ "  --stdin            Read JSON command from stdin (agent mode)\n"
  ++ "\n"
  ++ "Core:\n"
  ++ "  init [URL]                    Create state directory and default config\n"
  ++ "  login --user U [--password P] Authenticate, persist token\n"
  ++ "  logout                        Clear persisted token\n"
  ++ "  show                          Display current state (project, auth status)\n"
  ++ "\n"
  ++ "Project context:\n"
  ++ "  project list                  List accessible projects\n"
  ++ "  project set <slug|id>         Switch active project\n"
  ++ "  project get                   Show active project details\n"
  ++ "\n"
  ++ "Task operations:\n"
  ++ "  task list [--status S]        List tasks in active project\n"
  ++ "  task create <subject>         Create task\n"
  ++ "  task get <id>                 Get task by ID\n"
  ++ "  task status <id> <status>    Change task status\n"
  ++ "  task comment <id> <text>     Comment on a task\n"
  ++ "\n"
  ++ "Epic operations:\n"
  ++ "  epic list                     List epics in active project\n"
  ++ "  epic get <id>                 Get epic details\n"
  ++ "\n"
  ++ "Sprint operations:\n"
  ++ "  sprint list                   List all sprints/milestones\n"
  ++ "  sprint show                   Show current sprint state\n"
  ++ "  sprint set <id>              Set active sprint context\n"
  ++ "\n"
  ++ "Issue operations:\n"
  ++ "  issue list                    List issues in active project\n"
  ++ "  issue get <id>                Get issue details\n"
  ++ "\n"
  ++ "Story operations:\n"
  ++ "  story list                    List stories in active project\n"
  ++ "  story get <id>                Get story details\n"
  ++ "\n"
  ++ "Wiki operations:\n"
  ++ "  wiki list                     List wiki pages in active project\n"
  ++ "  wiki get <id>                 Get wiki page details\n"
  ++ "\n"
  ++ "Global flags:\n"
  ++ "  --json                        Output JSON instead of text\n"
  ++ "  --base <url>                 Override base URL for this invocation\n"

||| Generate a short synopsis (first line of --help).
public export
usageSynopsis : String
usageSynopsis = "taiga-cli [OPTIONS] COMMAND"

||| Generate per-command help text for a single sub-command name.
||| Returns `Nothing` if the name is not recognised.
public export
commandHelp : String -> Maybe String
commandHelp "init"       = Just $ "init [BASE_URL]\n" ++
                                "    Initialize workspace state in ./.taiga/"
commandHelp "login"      = Just $ "login --user USERNAME [--password PASSWORD]\n" ++
                                "    Authenticate with Taiga and persist token.\n" ++
                                "    If --password is omitted, the password is read interactively.\n" ++
                                "    WARNING: Passing --password on the command line is insecure."
commandHelp "logout"     = Just $ "logout\n" ++
                                "    Clear persisted authentication token."
commandHelp "show"       = Just $ "show\n" ++
                                "    Display current workspace state."
commandHelp "project"    = Just $ "project {list|set <slug>|get}\n" ++
                                "    Manage active project context."
commandHelp "task"       = Just $ "task {list|create|get|status|comment}\n" ++
                                "    Manage tasks in active project."
commandHelp "epic"       = Just $ "epic {list|get}\n" ++
                                "    Manage epics in active project."
commandHelp "sprint"     = Just $ "sprint {list|show|set}\n" ++
                                "    Manage sprints/milestones."
commandHelp "issue"      = Just $ "issue {list|get}\n" ++
                                "    Manage issues in active project."
commandHelp "story"      = Just $ "story {list|get}\n" ++
                                "    Manage stories in active project."
commandHelp "wiki"       = Just $ "wiki {list|get}\n" ++
                                "    Manage wiki pages in active project."
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
