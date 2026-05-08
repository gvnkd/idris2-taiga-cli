module Taiga.Auth
import JSON.FromJSON
import JSON.ToJSON
import JSON.Encoder
import Model.Auth
import Model.User
import Taiga.Api
import Taiga.Env

%language ElabReflection

public export
record LoginBody where
  constructor MkLoginBody
  type : String
  username : String
  password : String

public export
implementation ToJSON LoginBody where
  toJSON b =
    object [jpair "type" b.type, jpair "username" b.username, jpair "password" b.password]

public export
login : HasIO io => (base : String) -> (creds : Credentials) -> io (Either String Token)
login base creds = do
  let body : _ = encode $ MkLoginBody "normal" creds.username creds.password
  let url : _ = buildUrl ["auth"] [] base
  resp <- httpPost url Nothing body
  expectJson resp 200 "login"

public export
record RefreshBody where
  constructor MkRefreshBody
  refresh : String

public export
implementation ToJSON RefreshBody where
  toJSON b =
    object [jpair "refresh" b.refresh]

public export
refreshToken : HasIO io => (base : String) -> (refresh : String) -> io (Either String Token)
refreshToken base refreshTok = do
  let body : _ = encode $ MkRefreshBody refreshTok
  let url : _ = buildUrl ["auth", "refresh"] [] base
  resp <- httpPost url Nothing body
  expectJson resp 200 "token refresh"

public export
me : HasIO io => (base : String) -> (token : String) -> io (Either String User)
me base token = do
  let url : _ = buildUrl ["users", "me"] [] base
  resp <- httpGet url (Just token)
  expectJson resp 200 "get user profile"
