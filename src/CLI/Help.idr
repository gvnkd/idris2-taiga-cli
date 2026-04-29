||| Usage help text.
|||
||| Generates the `--help` / `-h` output describing all supported
||| flags and sub-commands.
module CLI.Help

import CLI.Args

||| Print the full usage message to stdout.
public export
usage : String

||| Generate a short synopsis (first line of --help).
public export
usageSynopsis : String

||| Generate per-command help text for a single sub-command name.
||| Returns `Nothing` if the name is not recognised.
public export
commandHelp : String -> Maybe String

||| List all recognised sub-command / flag names.
public export
knownCommands : List String
