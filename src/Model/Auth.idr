||| Authentication credentials and tokens.
module Model.Auth

import JSON.Derive
import Model.Common

%language ElabReflection

||| Username or email and plaintext password for login.
public export
record Credentials where
  constructor MkCredentials
  user : String
  pass : String

%runElab derive "Credentials" [Show,ToJSON,FromJSON]

||| Bearer token and optional refresh token returned by the API.
public export
record Token where
  constructor MkToken
  token : String
  refresh : Maybe String

%runElab derive "Token" [Show,ToJSON,FromJSON]
