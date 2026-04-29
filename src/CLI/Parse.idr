||| Command-line argument parser.
|||
||| Hand-rolled parser: consumes `List String` from `getArgs` and
||| produces a `CLIArgs` value.  Unrecognised flags or missing
||| arguments yield a parse error string.
module CLI.Parse

import CLI.Args
import Model.Common
import Data.Vect

||| Result of parsing the command-line arguments.
record ParseResult where
  constructor MkParseResult
  cli_args : CLIArgs
  base_url : Maybe String

||| Parse a list of raw command-line arguments.
|||
||| Returns `Left err` on parse failure, or `Right result` with the
||| parsed `CLIArgs` and any global `--base` that was supplied.
public export
parseArgs : List String -> Either String ParseResult

||| Attempt to read a non-negative integer from a string argument.
readNat64 : String -> Either String Bits64

||| Attempt to read a positive integer (version / id helper).
readNat32 : String -> Either String Bits32

||| Consume the next argument from the front of the list,
||| returning `Left` if the list is empty.
nextArg : List String -> Either String String

||| Check whether a flag string is one of the known short forms.
isShortFlag : String -> Bool

||| Check whether a flag string is a long form (starts with `--`).
isLongFlag : String -> Bool
