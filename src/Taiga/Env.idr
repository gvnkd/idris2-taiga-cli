||| API environment: base URL and auth token.
|||
||| Used as an auto-implicit parameter so that every Taiga endpoint
||| gets base URL and bearer token without repeating them in every
||| function signature.
module Taiga.Env

import Data.Bits
import Data.List
import JSON.FromJSON
import Taiga.Api

%language ElabReflection

||| Build a query string from key-value pairs.
public export
buildQueryString : List (String, String) -> String
buildQueryString [] = ""
buildQueryString kvs =
  let pairs := map (\(k, v) => k ++ "=" ++ v) kvs
   in "?" ++ concat (intersperse "&" pairs)

||| Parse a string as a Bits64 value.
public export
parseBits64 : String -> Bits64
parseBits64 = cast

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

||| Parse an HTTP response as JSON on a specific status code.
||| Returns `Right` with the decoded value if the status matches,
||| otherwise returns `Left` with an error message.
public export
expectJson :
     FromJSON a =>
     HasIO io =>
     (resp : HttpResponse) ->
     (okStatus : Bits16) ->
     (errMsg   : String) ->
     io (Either String a)
expectJson resp okStatus errMsg =
  pure $ if resp.status.code == okStatus
           then decodeEither resp.body
           else Left $ errMsg ++ " failed with status "
                         ++ show resp.status.code

||| Check an HTTP response for a specific status code without parsing JSON.
||| Returns `Right ()` on match, otherwise `Left` with an error message.
public export
expectOk :
     HasIO io =>
     (resp : HttpResponse) ->
     (okStatus : Bits16) ->
     (errMsg   : String) ->
     io (Either String ())
expectOk resp okStatus errMsg =
  pure $ if resp.status.code == okStatus
           then Right ()
           else Left $ errMsg ++ " failed with status "
                         ++ show resp.status.code

||| Parse an HTTP response returning raw body on success.
public export
expectRaw :
     HasIO io =>
     (resp : HttpResponse) ->
     (okStatus : Bits16) ->
     (errMsg   : String) ->
     io (Either String String)
expectRaw resp okStatus errMsg =
  pure $ if resp.status.code == okStatus
           then Right resp.body
           else Left $ errMsg ++ " failed with status "
                         ++ show resp.status.code
