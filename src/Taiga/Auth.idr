||| Login, token refresh, and authenticated-user profile endpoints.
|||
||| Taiga API endpoints (base URL is e.g. http://taiga.bigdesk/api/v1):
|||   POST /auth        — login with type "normal"
|||   POST /auth/refresh — refresh token
|||   GET  /user        — current user profile
module Taiga.Auth

import JSON.FromJSON
import JSON.ToJSON
import Model.Auth
import Model.User
import Taiga.Api
import Taiga.Env

%language ElabReflection

||| Exchange username and password for an auth token.
||| Sends {"type":"normal","username":"…","password":"…"} to POST /auth.
public export
login :
     HasIO io
  => (base : String)
  -> (creds : Credentials)
  -> io (Either String Token)
login base creds = do
   resp <- httpPost (base ++ "/auth") Nothing bodyStr
   expectJson resp 200 "login"
   where
     bodyStr : String
     bodyStr = "{\"type\":\"normal\",\"username\":\"" ++ creds.username
               ++ "\",\"password\":\"" ++ creds.password ++ "\"}"

||| Refresh an expiring token using its refresh counterpart.
||| Sends {"refresh":"…"} to POST /auth/refresh.
public export
refreshToken :
     HasIO io
  => (base : String)
  -> (refresh : String)
  -> io (Either String Token)
refreshToken base refreshTok = do
   resp <- httpPost (base ++ "/auth/refresh") Nothing bodyStr
   expectJson resp 200 "token refresh"
   where
     bodyStr : String
     bodyStr = "{\"refresh\":\"" ++ refreshTok ++ "\"}"

||| Get the profile of the currently authenticated user.
public export
me :
     HasIO io
  => (base : String)
  -> (token : String)
  -> io (Either String User)
me base token = do
   resp <- httpGet (base ++ "/users/me") (Just token)
   expectJson resp 200 "get user profile"

