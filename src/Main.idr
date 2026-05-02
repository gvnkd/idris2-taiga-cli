||| CLI entry point.
|||
||| Three modes of operation:
|||
||| 1. **Agent mode** (default): reads a JSON request from stdin,
|||    dispatches to the appropriate command handler, and writes a
|||    JSON response to stdout.  Used by AI agents.
|||
||| 2. **CLI mode** (legacy flags): activated when `getArgs` returns
|||    flags like `--list-epics`, `--login`, etc.
|||
||| 3. **Subcommand mode** (new): verb-noun commands like
|||    `taiga-cli task list`, `taiga-cli project set taiga`.
module Main

import CLI.Args
import CLI.Help
import CLI.Parse
import CLI.Output
import CLI.Subcommand
import Command
import Model.Auth
import Protocol.Request
import Protocol.Response
import State.Config
import System.File
import System
import Data.List
import Data.String

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

||| Run the legacy CLI path: parse flags, dispatch command, print result.
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

||| Strip `--json` from args and return (remaining args, wants JSON).
stripJsonFlag : List String -> (List String, Bool)
stripJsonFlag args = go args False
  where
    go : List String -> Bool -> (List String, Bool)
    go []        acc = ([], acc)
    go ("--json" :: xs) acc = go xs True
    go (x :: xs) acc =
      let (rest, flag) = go xs acc
       in (x :: rest, flag)

||| Check if args contain --help or -h.
hasHelpFlag : List String -> Bool
hasHelpFlag args = any (\x => x == "--help" || x == "-h") args

||| Run the new subcommand path.
runSubcommand : List String -> IO ()
runSubcommand rawArgs = do
  let (args, wantJson) := stripJsonFlag rawArgs
  if hasHelpFlag args
    then putStrLn usage
    else do
      fmt <- if wantJson then pure JsonFmt else resolveOutputFormat
      case parseAction args of
        Left err =>
          if wantJson
            then do
              ignore $ fPutStrLn stderr ("error: " ++ err)
              exitWith (ExitFailure 1)
            else do
              putStrLn $ "error: " ++ err
              exitWith (ExitFailure 1)
        Right action => do
          result <- executeAction action
          case result of
            Left err =>
              if wantJson
                then do
                  ignore $ fPutStrLn stderr ("error: " ++ err)
                  exitWith (ExitFailure 1)
                else do
                  putStrLn $ "error: " ++ err
                  exitWith (ExitFailure 1)
            Right cr => do
              putStrLn $ renderCmdResult fmt cr
              exitWith ExitSuccess

||| Check if args look like legacy flags (start with --).
looksLikeFlags : List String -> Bool
looksLikeFlags []     = False
looksLikeFlags (x::_) = Data.String.isPrefixOf "--" x

||| Top-level entry point.
|||
||| If `getArgs` returns non-empty, route to the appropriate mode.
main : IO ()
main = do
  args <- getArgs
  let args'    := drop 1 args
      (argsNoJson, _) := stripJsonFlag args'
  case args' of
    []    => putStrLn usage
    _     =>
      if looksLikeFlags argsNoJson
        then runCLI args'
        else runSubcommand args'
