||| Request envelope parser.
|||
||| Each invocation reads one JSON object from stdin:
|||   {"cmd":"…","args":{…},"auth":{…},"base":"…"}
module Protocol.Request

import JSON.Derive
import Model.Auth

%language ElabReflection

||| Authentication information carried with a request.
public export
data AuthInfo : Type where
  TokenAuth    : String -> AuthInfo
  CredentialAuth : Credentials -> AuthInfo

%runElab derive "AuthInfo" [Show,ToJSON,FromJSON]

||| Top-level request envelope received from the agent.
public export
record Request where
  constructor MkRequest
  cmd : String
  args : String
  auth : Maybe AuthInfo
  base : Maybe String

%runElab derive "Request" [Show,ToJSON,FromJSON]

||| Parse a raw JSON string into a Request.
parseRequest : String -> Either String Request
parseRequest = ?rhs_parseRequest
