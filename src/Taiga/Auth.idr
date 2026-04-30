||| Login, token refresh, and authenticated-user profile endpoints.
|||
||| Taiga API endpoints (base URL is e.g. http://taiga.bigdesk/api/v1):
|||   POST /auth        — login with type "normal"
|||   POST /auth/refresh — refresh token
|||   GET  /user        — current user profile
module Taiga.Auth

import JSON.FromJSON
import JSON.ToJSON
import JSON.Encoder
import Model.Auth
import Model.User
import Taiga.Api
import Taiga.Env

%language ElabReflection

||| Request body for login endpoint.
public export
record LoginBody where
  constructor MkLoginBody
  type     : String
  username : String
  password : String

public export
ToJSON LoginBody where
  toJSON b =
    object
      [ jpair "type" b.type
      , jpair "username" b.username
      , jpair "password" b.password
      ]

||| Exchange username and password for an auth token.
||| Sends {"type":"normal","username":"…","password":"…"} to POST /auth.
public export
login :
     HasIO io
  => (base : String)
  -> (creds : Credentials)
  -> io (Either String Token)
login base creds = do
   let body := encode $ MkLoginBody "normal" creds.username creds.password
       url  := buildUrl ["auth"] [] base
   resp <- httpPost url Nothing body
   expectJson resp 200 "login"

||| Request body for token refresh endpoint.
public export
record RefreshBody where
  constructor MkRefreshBody
  refresh : String

public export
ToJSON RefreshBody where
  toJSON b = object [jpair "refresh" b.refresh]

||| Refresh an expiring token using its refresh counterpart.
||| Sends {"refresh":"…"} to POST /auth/refresh.
public export
refreshToken :
     HasIO io
  => (base : String)
  -> (refresh : String)
  -> io (Either String Token)
refreshToken base refreshTok = do
   let body := encode $ MkRefreshBody refreshTok
       url  := buildUrl ["auth", "refresh"] [] base
   resp <- httpPost url Nothing body
   expectJson resp 200 "token refresh"

||| Get the profile of the currently authenticated user.
public export
me :
     HasIO io
  => (base : String)
  -> (token : String)
  -> io (Either String User)
me base token = do
   let url := buildUrl ["users", "me"] [] base
   resp <- httpGet url (Just token)
   expectJson resp 200 "get user profile"

