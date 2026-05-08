module Model.Auth
import JSON.Derive
import Model.Common

%language ElabReflection

public export
record Credentials where
  constructor MkCredentials
  username : String
  password : String

%runElab derive "Credentials" [Show, ToJSON, FromJSON]

public export
record Token where
  constructor MkToken
  auth_token : String
  refresh : Maybe String

%runElab derive "Token" [Show, ToJSON, FromJSON]
