||| Dual-Format Output.
|||
||| Format any result as human-readable text or JSON.
module CLI.Output

import State.Config
import JSON.Derive
import JSON.ToJSON
import JSON.FromJSON
import JSON.Encoder
import JSON.Parser

%language ElabReflection

||| A unified result that carries both human-readable content and
||| structured data.
public export
record CmdResult where
  constructor MkCmdResult
  status   : Bits8
  message  : String
  payload  : String

||| Encode a CmdResult to JSON string.  Payload is embedded raw (not
||| double-encoded). Uses ToJSON for status/message and splices in the
||| pre-formatted payload as-is.
public export
ToJSON CmdResult where
  toJSON cr = object
    [ jpair "status" cr.status
    , jpair "message" cr.message
    ]

encodeCmdResult : CmdResult -> String
encodeCmdResult cr =
  "{\"status\":" ++ show cr.status
    ++ ",\"message\":" ++ JSON.ToJSON.encode cr.message
    ++ ",\"payload\":" ++ cr.payload ++ "}"

||| Convenience constructor for success.
public export
cmdOk : ToJSON a => String -> a -> CmdResult
cmdOk msg val = MkCmdResult 0 msg (encode val)

||| Convenience constructor for success with a raw (already-JSON) payload.
public export
cmdOkRaw : String -> String -> CmdResult
cmdOkRaw msg raw = MkCmdResult 0 msg raw

||| Convenience constructor for error.
public export
cmdError : String -> CmdResult
cmdError err = MkCmdResult 1 err "null"

||| Convenience constructor for info.
public export
cmdInfo : String -> CmdResult
cmdInfo msg = MkCmdResult 2 msg "null"

||| Structured result for delete operations.
public export
record DeleteResult where
  constructor MkDeleteResult
  entity : String
  id     : Bits64

%runElab derive "DeleteResult" [Show,ToJSON,FromJSON]

||| Pretty-print JSON payload for text mode.
||| If the payload is not "null", pretty-prints it indented below the status
||| line.  Otherwise returns just the status line.
public export
renderPayload : String -> String
renderPayload "null" = ""
renderPayload json  = "\n" ++ prettyPrintJSON json

  where
    ||| Simple JSON pretty-printer: add newlines after each comma and
    ||| brace to make the output readable.
    prettyPrintJSON : String -> String
    prettyPrintJSON s = go (unpack s) 0
      where
        indent : Nat -> String
        indent n = concat $ Data.List.replicate (n * 2) " "

        go : List Char -> Nat -> String
        go []          _     = ""
        go ('{' :: cs) depth = "{\n" ++ indent (S depth) ++ go cs (S depth)
        go ('[' :: cs) depth = "[\n" ++ indent (S depth) ++ go cs (S depth)
        go (',' :: cs) depth = ",\n" ++ indent depth ++ go cs depth
        go ('}' :: cs) depth = "\n" ++ indent (minus depth 1) ++ "}" ++ go cs (minus depth 1)
        go (']' :: cs) depth = "\n" ++ indent (minus depth 1) ++ "]" ++ go cs (minus depth 1)
        go (c   :: cs) depth = pack [c] ++ go cs depth

||| Format a CmdResult for display.
public export
renderCmdResult : OutputFormat -> CmdResult -> String
renderCmdResult JsonFmt cr = encodeCmdResult cr
renderCmdResult TextFmt cr =
  let header := case cr.status of
                   0 => "[OK]   " ++ cr.message
                   1 => "[ERR]  " ++ cr.message
                   2 => "[INFO] " ++ cr.message
                   _ => cr.message
   in header ++ renderPayload cr.payload
