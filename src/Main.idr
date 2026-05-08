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

readStdin : {auto _ : HasIO io} -> io String
readStdin = do
  raw <- fRead stdin
  case raw of
    Right s => pure s
    Left err => pure $ "readStdin failed: " ++ show err

writeStdout : {auto _ : HasIO io} -> String -> io ()
writeStdout =
  putStr

cliError : String -> IO ()
cliError msg = do
  putStrLn $ "error: " ++ msg

cliPrintResponse : Response -> IO ()
cliPrintResponse =
  writeStdout . serializeResponse

auth_to_token' : AuthInfo -> Maybe Token
auth_to_token' (TokenAuth t) =
  Just $ ((MkToken {auth_token = t}) {refresh = Nothing})
auth_to_token' (CredentialAuth _) =
  Nothing

runAgent : IO ()
runAgent = do
  raw <- readStdin
  case parseRequest raw of
    Left err => let response = Err $ MkErrorResponse False "parse_error" err in writeStdout (serializeResponse response)
    Right req => let token = case req.auth of
                               Nothing => Nothing
                               Just auth => auth_to_token' auth in case parseCommand req.cmd req.args of
                                                                     Left err => let response = Err $ MkErrorResponse False "bad_command" err in writeStdout (serializeResponse response)
                                                                     Right command => do
                                                                                        resp <- dispatchCommand command token req.base
                                                                                        writeStdout (serializeResponse resp)

runCLI : List String -> IO ()
runCLI rawArgs =
  case parseArgs rawArgs of
    Left err => cliError err
    Right res => let base = res.base_url in let command = toCommand res.cli_args in case res.cli_args of
                                                                                      ArgStdin => runAgent
                                                                                      ArgHelp => putStrLn usage
                                                                                      _ => do
                                                                                             resp <- dispatchCommand command Nothing base
                                                                                             cliPrintResponse resp

stripJsonFlag : List String -> (List String, Bool)
stripJsonFlag args =
  go args False
  where
    go : List String -> Bool -> (List String, Bool)
    go [] acc =
      ([], acc)
    go ("--json" :: xs) acc =
      go xs True
    go (x :: xs) acc =
      let (rest, flag) = go xs acc in (x :: rest, flag)

hasHelpFlag : List String -> Bool
hasHelpFlag args =
  any (\x => x == "--help" || x == "-h") args

runSubcommand : List String -> IO ()
runSubcommand rawArgs = do
  let (args, wantJson) = stripJsonFlag rawArgs
  if hasHelpFlag args
    then putStrLn usage
      else
        do
          fmt <- if wantJson then pure JsonFmt else resolveOutputFormat
          case parseAction args of
            Left err => if wantJson
                          then do
                                 ignore $ fPutStrLn stderr ("error: " ++ err)
                                 exitWith (ExitFailure 1)
                            else
                              do
                                putStrLn $ "error: " ++ err
                                exitWith (ExitFailure 1)
            Right action => do
                              result <- executeAction action
                              case result of
                                Left err => if wantJson
                                              then do
                                                     ignore $ fPutStrLn stderr ("error: " ++ err)
                                                     exitWith (ExitFailure 1)
                                                else
                                                  do
                                                    putStrLn $ "error: " ++ err
                                                    exitWith (ExitFailure 1)
                                Right cr => do
                                              putStrLn $ renderCmdResult fmt cr
                                              exitWith ExitSuccess

looksLikeFlags : List String -> Bool
looksLikeFlags [] =
  False
looksLikeFlags (x :: _) =
  Data.String.isPrefixOf "--" x
-- Version flag handling (check before other routing)
isVersionFlag : List String -> Bool
isVersionFlag args =
  any (\x => x == "--version" || x == "-v") args

versionPrint : IO ()
versionPrint =
  putStrLn "taiga-cli version 0.1.0"

main : IO ()
main = do
  args <- getArgs
  let args' : _ = drop 1 args
  let (argsNoJson, _) = stripJsonFlag args'
  if isVersionFlag args'
    then versionPrint
      else
        case args' of
          [] => putStrLn usage
          _ => if looksLikeFlags argsNoJson
                 then runCLI args'
                   else
                     runSubcommand args'
-- Handle version flags immediately before other routing
