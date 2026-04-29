||| CLI entry point.
|||
||| Reads one JSON request from stdin, dispatches to the appropriate
||| command handler, and writes one JSON response to stdout.
module Main

import Command
import Model.Auth
import Protocol.Request
import Protocol.Response
import System.File

||| Read raw JSON from stdin.
readStdin :
     HasIO io
  => io String
readStdin = do
  raw <- fRead stdin
  case raw of
    Right s  => pure s
    Left err => pure $ "readStdin failed: " ++ show err

||| Write a JSON string to stdout.
writeStdout :
     HasIO io
  => String -> io ()
writeStdout = putStr

||| Extract a Token from AuthInfo.
auth_to_token' : AuthInfo -> Maybe Token
auth_to_token' (TokenAuth t)     = Just $ MkToken { auth_token = t, refresh = Nothing }
auth_to_token' (CredentialAuth _) = Nothing

||| Top-level entry point.
main : IO ()
main = do
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
