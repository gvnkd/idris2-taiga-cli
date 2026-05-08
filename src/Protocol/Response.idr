module Protocol.Response
import JSON.Derive

%language ElabReflection

public export
record Success where
  constructor MkSuccess
  ok : Bool
  payload : String

%runElab derive "Success" [Show, ToJSON, FromJSON]

public export
record ErrorResponse where
  constructor MkErrorResponse
  ok : Bool
  err : String
  msg : String

%runElab derive "ErrorResponse" [Show, ToJSON, FromJSON]

public export
data Response : Type where
  Ok : Success -> Response
  Err : ErrorResponse -> Response

%runElab derive "Response" [Show, ToJSON, FromJSON]

public export
serializeResponse : Response -> String
serializeResponse =
  encode
