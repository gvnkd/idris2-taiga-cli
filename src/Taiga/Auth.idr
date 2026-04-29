||| Login, token refresh, and authenticated-user profile endpoints.
module Taiga.Auth

import JSON.FromJSON
import JSON.ToJSON
import Model.Auth
import Model.User
import Taiga.Api

%language ElabReflection

||| Exchange username and password for an auth token.
public export
login :
      HasIO io
   => (base : String)
   -> (creds : Credentials)
   -> io (Either String Token)
login base creds
  = do let body := encode creds
       resp <- httpPost (base ++ "/user/authenticate") Nothing body
       case resp.status.code of
         200 => case decodeEither resp.body of
                  Left  err  => pure $ Left err
                  Right tok => pure $ Right tok
         _     => pure $ Left ("login failed with status " ++ show resp.status.code)

||| Refresh an expiring token using its refresh counterpart.
public export
refreshToken :
      HasIO io
   => (base : String)
   -> (refresh : String)
   -> io (Either String Token)
refreshToken base refreshTok
  = do let body := "{\"refresh\":\"" ++ refreshTok ++ "\""
       resp <- httpPost (base ++ "/user/refresh_token") Nothing body
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
