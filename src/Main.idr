||| CLI entry point.
|||
||| Reads one JSON request from stdin, dispatches to the appropriate
||| command handler, and writes one JSON response to stdout.
module Main

import Command
import Protocol.Request
import Protocol.Response
import System.File

||| Read raw JSON from stdin.
readStdin :
     HasIO io
  => io String
readStdin = ?rhs_readStdin

||| Write a JSON string to stdout.
writeStdout :
     HasIO io
  => String -> io ()
writeStdout = ?rhs_writeStdout

||| Top-level entry point.
main : IO ()
main = ?rhs_main
