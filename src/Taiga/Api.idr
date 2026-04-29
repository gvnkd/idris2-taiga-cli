||| HTTP client wrapper — delegates to curl subprocess.
|||
||| Provides typed GET / POST / PUT / PATCH / DELETE helpers
||| that handle JSON bodies and Bearer-token authentication.
module Taiga.Api

import JSON.Derive
import System.File

%language ElabReflection

||| HTTP status code.
public export
record StatusCode where
  constructor MkStatusCode
  code : Bits16

%runElab derive "StatusCode" [Show,Eq]

||| Result of an HTTP request: status code and response body.
public export
record HttpResponse where
  constructor MkHttpResponse
  status : StatusCode
  body : String

%runElab derive "HttpResponse" [Show]

||| Perform a GET request and return the response body.
httpGet :
     HasIO io
  => (url : String)
  -> (auth : Maybe String)
  -> io HttpResponse
httpGet = ?rhs_httpGet

||| Perform a POST request with a JSON body.
httpPost :
     HasIO io
  => (url : String)
  -> (auth : Maybe String)
  -> (body : String)
  -> io HttpResponse
httpPost = ?rhs_httpPost

||| Perform a PUT request with a JSON body.
httpPut :
     HasIO io
  => (url : String)
  -> (auth : Maybe String)
  -> (body : String)
  -> io HttpResponse
httpPut = ?rhs_httpPut

||| Perform a PATCH request with a JSON body.
httpPatch :
     HasIO io
  => (url : String)
  -> (auth : Maybe String)
  -> (body : String)
  -> io HttpResponse
httpPatch = ?rhs_httpPatch

||| Perform a DELETE request.
httpDelete :
     HasIO io
  => (url : String)
  -> (auth : Maybe String)
  -> io HttpResponse
httpDelete = ?rhs_httpDelete
