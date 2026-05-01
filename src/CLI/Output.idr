||| Dual-Format Output.
|||
||| Format any result as human-readable text or JSON.
module CLI.Output

import State.Config
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
||| double-encoded).
encodeCmdResult : CmdResult -> String
encodeCmdResult cr =
  "{\"status\":" ++ show cr.status ++
  ",\"message\":\"" ++ escapeString cr.message ++ "\"" ++
  ",\"payload\":" ++ cr.payload ++ "}"

  where
    escapeChar : Char -> String
    escapeChar '"'  = "\\\""
    escapeChar '\\' = "\\\\"
    escapeChar '\n' = "\\n"
    escapeChar '\r' = "\\r"
    escapeChar '\t' = "\\t"
    escapeChar c    = pack [c]

    escapeString : String -> String
    escapeString s = concat $ map escapeChar (unpack s)

||| Convenience constructor for success.
public export
cmdOk : ToJSON a => String -> a -> CmdResult
cmdOk msg val = MkCmdResult 0 msg (encode val)

||| Convenience constructor for error.
public export
cmdError : String -> CmdResult
cmdError err = MkCmdResult 1 err "null"

||| Convenience constructor for info.
public export
cmdInfo : String -> CmdResult
cmdInfo msg = MkCmdResult 2 msg "null"

||| Format a CmdResult for display.
public export
renderCmdResult : OutputFormat -> CmdResult -> String
renderCmdResult JsonFmt cr = encodeCmdResult cr
renderCmdResult TextFmt cr =
  case cr.status of
    0 => "[OK]   " ++ cr.message
    1 => "[ERR]  " ++ cr.message
    2 => "[INFO] " ++ cr.message
    _ => cr.message
