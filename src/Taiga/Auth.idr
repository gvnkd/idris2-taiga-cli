||| Login, token refresh, and authenticated-user profile endpoints.
module Taiga.Auth

import JSON.FromJSON
import JSON.ToJSON
import Model.Auth
import Model.User
import Taiga.Api

%language ElabReflection

||| Exchange username and password for an auth token.
login :
     HasIO io
  => (base : String)
  -> (creds : Credentials)
  -> io (Either String Token)
login = ?rhs_login

||| Refresh an expiring token using its refresh counterpart.
refreshToken :
     HasIO io
  => (base : String)
  -> (refresh : String)
  -> io (Either String Token)
refreshToken = ?rhs_refreshToken

||| Get the profile of the currently authenticated user.
me :
     HasIO io
  => (base : String)
  -> (token : String)
  -> io (Either String User)
me = ?rhs_me
