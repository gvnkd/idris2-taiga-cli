||| Dual-Format Output.
|||
||| Format any result as human-readable text or JSON.
||| Text mode prints a status line plus optional plain-text details.
||| JSON mode prints a single valid JSON object with no extra text.
module CLI.Output

import State.Config
import JSON.Derive
import JSON.ToJSON
import JSON.FromJSON
import JSON.Encoder

%language ElabReflection

||| A unified result that carries both human-readable text content and
||| a JSON payload. The renderer picks the appropriate field based on
||| the output format.
public export
record CmdResult where
  constructor MkCmdResult
  status   : Bits8
  message  : String
  text     : String   -- plain text for text mode (no JSON)
  payload  : String   -- JSON payload for JSON mode

||| Encode a CmdResult to a JSON string.
||| Output is a single valid JSON object: {"status":N,"message":"...","payload":...}
public export
encodeCmdResult : CmdResult -> String
encodeCmdResult cr =
  "{\"status\":" ++ show cr.status
    ++ ",\"message\":" ++ JSON.ToJSON.encode cr.message
    ++ ",\"payload\":" ++ cr.payload ++ "}"

||| Convenience constructor for success with a JSON-serialisable value.
||| Text mode shows only the message line (no JSON mixed in).
public export
cmdOk : ToJSON a => String -> a -> CmdResult
cmdOk msg val = MkCmdResult 0 msg "" (encode val)

||| Convenience constructor for success with a raw (already-JSON) payload.
||| Text mode shows only the message line.
public export
cmdOkRaw : String -> String -> CmdResult
cmdOkRaw msg raw = MkCmdResult 0 msg "" raw

||| Convenience constructor for error.
||| Text mode shows only the error message line.
public export
cmdError : String -> CmdResult
cmdError err = MkCmdResult 1 err "" "null"

||| Convenience constructor for info.
||| Text mode shows only the info message line.
public export
cmdInfo : String -> CmdResult
cmdInfo msg = MkCmdResult 2 msg "" "null"

||| Structured result for delete operations.
public export
record DeleteResult where
  constructor MkDeleteResult
  entity : String
  id     : Bits64

%runElab derive "DeleteResult" [Show,ToJSON,FromJSON]

||| Format a CmdResult for display.
||| JSON mode:  pure JSON object only (no prefix text, pipeable to jq).
||| Text mode:  status line only, no JSON payload mixed in.
public export
renderCmdResult : OutputFormat -> CmdResult -> String
renderCmdResult JsonFmt cr = encodeCmdResult cr
renderCmdResult TextFmt cr =
  case cr.status of
    0 => "[OK]   " ++ cr.message
    1 => "[ERR]  " ++ cr.message
    2 => "[INFO] " ++ cr.message
    _ => cr.message
