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

%language ElabReflection

||| Exchange username and password for an auth token.
||| Sends {"type":"normal","username":"…","password":"…"} to POST /auth.
public export
login :
      HasIO io
   => (base : String)
   -> (creds : Credentials)
   -> io (Either String Token)
login base creds
  = do let body := "{\"type\":\"normal\",\"username\":\"" ++ creds.username ++ "\",\"password\":\"" ++ creds.password ++ "\"}"
       resp <- httpPost (base ++ "/auth") Nothing body
       case resp.status.code of
         200 => case decodeEither resp.body of
                  Left  err  => pure $ Left err
                  Right tok => pure $ Right tok
         _     => pure $ Left ("login failed with status " ++ show resp.status.code)

||| Refresh an expiring token using its refresh counterpart.
||| Sends {"refresh":"…"} to POST /auth/refresh.
public export
refreshToken :
      HasIO io
   => (base : String)
   -> (refresh : String)
   -> io (Either String Token)
refreshToken base refreshTok
  = do let body := "{\"refresh\":\"" ++ refreshTok ++ "\""
       resp <- httpPost (base ++ "/auth/refresh") Nothing body
       case resp.status.code of
         200 => case decodeEither resp.body of
                  Left  err  => pure $ Left err
                  Right tok => pure $ Right tok
         _     => pure $ Left ("token refresh failed with status " ++ show resp.status.code)

||| Get the profile of the currently authenticated user.
public export
me :
     HasIO io
  => (base : String)
  -> (token : String)
  -> io (Either String User)
me base token
  = do resp <- httpGet (base ++ "/user") (Just token)
       case decodeEither resp.body of
         Left err  => pure $ Left err
         Right u   => pure $ Right u
