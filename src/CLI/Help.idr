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
  ++ "Authentication:\n"
  ++ "  --login USER PASS  Authenticate with username and password\n"
  ++ "  --me               Show current user profile\n"
  ++ "\n"
  ++ "Projects:\n"
  ++ "  --list-projects [OWNER]  List projects\n"
  ++ "\n"
  ++ "Epics:\n"
  ++ "  --list-epics PROJECT     List epics in PROJECT\n"
  ++ "  --get-epic [ID]          Get epic by ID\n"
  ++ "  --create-epic PROJECT TITLE [DESCRIPTION] [STATUS]\n"
  ++ "  --delete-epic ID         Delete epic\n"
  ++ "\n"
  ++ "Stories:\n"
  ++ "  --list-stories PROJECT   List user stories in PROJECT\n"
  ++ "  --get-story [ID]         Get story by ID\n"
  ++ "\n"
  ++ "Tasks:\n"
  ++ "  --list-tasks [PROJECT]   List tasks\n"
  ++ "  --get-task [ID]          Get task by ID\n"
  ++ "  --create-task PROJECT PARENT_TITLE [EPIC_ID] [ASSIGNEE] [STATUS]\n"
  ++ "\n"
  ++ "Issues:\n"
  ++ "  --list-issues PROJECT    List issues in PROJECT\n"
  ++ "  --get-issue [ID]         Get issue by ID\n"
  ++ "\n"
  ++ "Wiki:\n"
  ++ "  --list-wiki PROJECT      List wiki pages in PROJECT\n"
  ++ "  --create-wiki PROJECT TITLE CONTENT\n"
  ++ "\n"
  ++ "Milestones:\n"
  ++ "  --list-milestones PROJECT  List milestones in PROJECT\n"
  ++ "\n"
  ++ "Search:\n"
  ++ "  --search PROJECT QUERY   Search in PROJECT\n"

||| Generate a short synopsis (first line of --help).
public export
usageSynopsis : String
usageSynopsis = "taiga-cli [OPTIONS] COMMAND"

||| Generate per-command help text for a single sub-command name.
||| Returns `Nothing` if the name is not recognised.
public export
commandHelp : String -> Maybe String
commandHelp "login"       = Just $ "--login USERNAME PASSWORD\n" ++
                               "    Authenticate with Taiga and receive a token."
commandHelp "me"          = Just $ "--me\n" ++
                               "    Show the current authenticated user's profile."
commandHelp "list-projects" = Just $ "--list-projects [OWNER]\n" ++
                               "    List projects, optionally filtered by owner."
commandHelp "list-epics"  = Just $ "--list-epics PROJECT\n" ++
                               "    List epics in the given project (slug or ID)."
commandHelp "list-tasks"  = Just $ "--list-tasks [PROJECT]\n" ++
                               "    List tasks, optionally filtered by project."
commandHelp _             = Nothing

||| List all recognised sub-command / flag names.
public export
knownCommands : List String
knownCommands =
  [ "help"
  , "login"
  , "me"
  , "list-projects"
  , "list-epics"
  , "list-stories"
  , "list-tasks"
  , "list-issues"
  , "list-wiki"
  , "list-milestones"
  ]