||| Authentication credentials and tokens.
module Model.Auth

import JSON.Derive
import Model.Common

%language ElabReflection

||| Username and plaintext password for login.
public export
record Credentials where
  constructor MkCredentials
  username : String
  password : String

%runElab derive "Credentials" [Show,ToJSON,FromJSON]

||| Bearer token and optional refresh token returned by the API.
||| Taiga returns "auth_token" for the access token and "refresh" for
||| the long-lived refresh token.
public export
record Token where
  constructor MkToken
  auth_token : String
  refresh : Maybe String

%runElab derive "Token" [Show,ToJSON,FromJSON]
