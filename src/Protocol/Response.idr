||| Response envelope serialiser (compact JSON output).
|||
||| Success:  {"ok":true,"data":{…}}
||| Error:    {"ok":false,"err":"…","msg":"…"}
module Protocol.Response

import JSON.Derive

%language ElabReflection

||| A successful response carrying an arbitrary JSON payload.
public export
record Success where
  constructor MkSuccess
  ok : Bool
  payload : String

%runElab derive "Success" [Show,ToJSON,FromJSON]

||| An error response with a machine-readable code and human message.
public export
record ErrorResponse where
  constructor MkErrorResponse
  ok : Bool
  err : String
  msg : String

%runElab derive "ErrorResponse" [Show,ToJSON,FromJSON]

||| Unified response type.
public export
data Response : Type where
  Ok    : Success     -> Response
  Err   : ErrorResponse -> Response

%runElab derive "Response" [Show,ToJSON,FromJSON]

||| Serialize a Response to a JSON string.
serializeResponse : Response -> String
serializeResponse = ?rhs_serializeResponse
