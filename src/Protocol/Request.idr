module Protocol.Request
import JSON.Derive
import Model.Auth

%language ElabReflection

public export
data AuthInfo : Type where
  TokenAuth : String -> AuthInfo
  CredentialAuth : Credentials -> AuthInfo

%runElab derive "AuthInfo" [Show, ToJSON, FromJSON]

public export
record Request where
  constructor MkRequest
  cmd : String
  args : String
  auth : Maybe AuthInfo
  base : Maybe String

%runElab derive "Request" [Show, ToJSON, FromJSON]

public export
parseRequest : String -> Either String Request
parseRequest =
  decodeEither
