||| CLI entry point.
|||
||| Two modes of operation:
|||
||| 1. **Agent mode** (default): reads a JSON request from stdin,
|||    dispatches to the appropriate command handler, and writes a
|||    JSON response to stdout.  Used by AI agents.
|||
||| 2. **CLI mode**: activated when `getArgs` returns non-empty.
|||    Parses human-friendly flags (`--list-epics`, `--login`, etc.)
|||    and dispatches directly.  Output is plain JSON to stdout.
module Main

import CLI.Args
import CLI.Help
import CLI.Parse
import Command
import Model.Auth
import Protocol.Request
import Protocol.Response
import System.File
import System
import Data.List

%language ElabReflection

||| Read raw JSON from stdin.
readStdin :
     {auto _ : HasIO io}
  -> io String
readStdin = do
  raw <- fRead stdin
  case raw of
    Right s  => pure s
    Left err => pure $ "readStdin failed: " ++ show err

||| Write a JSON string to stdout.
writeStdout :
     {auto _ : HasIO io}
  -> String -> io ()
writeStdout = putStr

||| Print a human-readable error and exit.
cliError : String -> IO ()
cliError msg = do
  putStrLn $ "error: " ++ msg

||| Format a Response as JSON and print to stdout.
cliPrintResponse : Response -> IO ()
cliPrintResponse = writeStdout . serializeResponse

||| Extract a Token from AuthInfo.
auth_to_token' : AuthInfo -> Maybe Token
auth_to_token' (TokenAuth t)     = Just $ MkToken { auth_token = t, refresh = Nothing }
auth_to_token' (CredentialAuth _) = Nothing

||| Run the agent path: read JSON from stdin, dispatch, write response.
runAgent : IO ()
runAgent = do
  raw <- readStdin
  case parseRequest raw of
    Left err =>
      let response := Err $ MkErrorResponse False "parse_error" err
       in writeStdout (serializeResponse response)
    Right req =>
      let token := case req.auth of
                      Nothing     => Nothing
                      Just auth   => auth_to_token' auth
       in case parseCommand req.cmd req.args of
            Left err =>
              let response := Err $ MkErrorResponse False "bad_command" err
               in writeStdout (serializeResponse response)
            Right command => do
              resp <- dispatchCommand command token req.base
              writeStdout (serializeResponse resp)

||| Run the CLI path: parse args, dispatch command, print result.
runCLI : List String -> IO ()
runCLI rawArgs =
  case parseArgs rawArgs of
    Left err => cliError err
    Right res =>
      let base    := res.base_url
          command := toCommand res.cli_args
       in case res.cli_args of
            ArgStdin => runAgent
            ArgHelp  => putStrLn usage
            _        => do
              resp <- dispatchCommand command Nothing base
              cliPrintResponse resp

||| Top-level entry point.
|||
||| If `getArgs` returns non-empty, enter CLI mode.
||| Otherwise, enter agent mode (read JSON from stdin).
main : IO ()
main = do
  args <- getArgs
  let args' := drop 1 args
  case args' of
    []    => putStrLn usage
    _     => runCLI args'