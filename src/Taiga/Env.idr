||| API environment: base URL and auth token.
|||
||| Used as an auto-implicit parameter so that every Taiga endpoint
||| gets base URL and bearer token without repeating them in every
||| function signature.
module Taiga.Env

import Taiga.Api

%language ElabReflection

||| Holds the base URL and bearer token for all API calls.
public export
record ApiEnv where
  constructor MkApiEnv
  base  : String
  token : String

||| Shorthand for authenticated GET.
public export
authGet :
     HasIO io
  => (env : ApiEnv)
  -> (url : String)
  -> io HttpResponse
authGet env url = httpGet url (Just env.token)

||| Shorthand for authenticated POST.
public export
authPost :
     HasIO io
  => (env : ApiEnv)
  -> (url : String)
  -> (body : String)
  -> io HttpResponse
authPost env url body = httpPost url (Just env.token) body

||| Shorthand for authenticated PUT.
public export
authPut :
     HasIO io
  => (env : ApiEnv)
  -> (url : String)
  -> (body : String)
  -> io HttpResponse
authPut env url body = httpPut url (Just env.token) body

||| Shorthand for authenticated DELETE.
public export
authDelete :
     HasIO io
  => (env : ApiEnv)
  -> (url : String)
  -> io HttpResponse
authDelete env url = httpDelete url (Just env.token)

||| Shorthand for authenticated PATCH.
public export
authPatch :
     HasIO io
  => (env : ApiEnv)
  -> (url : String)
  -> (body : String)
  -> io HttpResponse
authPatch env url body = httpPatch url (Just env.token) body
