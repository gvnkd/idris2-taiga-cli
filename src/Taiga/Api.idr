||| HTTP client wrapper — delegates to curl subprocess.
|||
||| Provides typed GET / POST / PUT / PATCH / DELETE helpers
||| that handle JSON bodies and Bearer-token authentication.
module Taiga.Api

import JSON.Derive
import System.File
import System.File.Process
import System
import Data.String

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

||| Parse curl output into HttpResponse.
||| Curl output format: <body>\n<status_code>
parseHttpResponse : String -> HttpResponse
parseHttpResponse text =
  case reverse (lines text) of
    []       => MkHttpResponse (MkStatusCode 0) ""
    [single] => MkHttpResponse (MkStatusCode 0) single
    (statusLine :: bodyLines) =>
      let body := concat $ map (\l => l ++ "\n") (reverse bodyLines)
          code := cast statusLine
       in MkHttpResponse (MkStatusCode code) body

||| Build curl command string for a GET request.
buildCurlGet : (url : String) -> (auth : Maybe String) -> String
buildCurlGet url auth =
  let authFlag := case auth of
                     Nothing    => ""
                     Just token => "--header \"Authorization: Bearer " ++ token ++ "\""
   in "curl -s -w \"\\n%{http_code}\" " ++ authFlag ++ " \"" ++ url ++ "\""

||| Run curl via popen, read all output, close pipe, return HttpResponse.
runCurlCmdIO : HasIO io => String -> io HttpResponse
runCurlCmdIO cmd'
  = do res <- popen (cmd' ++ " 2>&1") Read
       case res of
         Left  _     => pure (MkHttpResponse (MkStatusCode 1) "")
         Right f     => do body <- fRead f
                           pc <- pclose f
                           case body of
                             Left  _     => pure (MkHttpResponse (MkStatusCode 1) "")
                             Right text => pure (parseHttpResponse text)

||| Run a curl command and parse its output into an HttpResponse.
runCurlCmd :
     {auto _ : HasIO io}
  -> (cmd : String)
  -> io HttpResponse
runCurlCmd cmd = runCurlCmdIO cmd

||| Perform a GET request and return the response body.
public export
httpGet :
     HasIO io
  => (url : String)
  -> (auth : Maybe String)
  -> io HttpResponse
httpGet url auth = runCurlCmd (buildCurlGet url auth)

||| Build curl command for a POST request with JSON body.
buildCurlPost : (url : String) -> (auth : Maybe String) -> (body : String) -> String
buildCurlPost url auth body =
  let authFlag := case auth of
                      Nothing    => ""
                      Just token => "--header \"Authorization: Bearer " ++ token ++ "\""
      jsonFlag := "--header \"Content-Type: application/json\" --data '" ++ body ++ "'"
   in "curl -s -w \"\\n%{http_code}\" -X POST " ++ authFlag ++ " " ++ jsonFlag ++ " \"" ++ url ++ "\""

||| Perform a POST request with a JSON body.
public export
httpPost :
      HasIO io
   => (url : String)
   -> (auth : Maybe String)
   -> (body : String)
   -> io HttpResponse
httpPost url auth body = runCurlCmd (buildCurlPost url auth body)

||| Build curl command for a generic HTTP method with optional JSON body.
buildCurlMethod :
     (method : String)
  -> (url : String)
  -> (auth : Maybe String)
  -> (body : Maybe String)
  -> String
buildCurlMethod method url auth body =
  let authFlag := case auth of
                      Nothing    => ""
                      Just token => "--header \"Authorization: Bearer " ++ token ++ "\""
      bodyFlag := case body of
                      Nothing  => ""
                      Just b   => "--header \"Content-Type: application/json\" --data '" ++ b ++ "'"
   in "curl -s -w \"\\n%{http_code}\" -X " ++ method ++ " " ++ authFlag ++ " " ++ bodyFlag ++ " \"" ++ url ++ "\""

||| Perform a PUT request with a JSON body.
public export
httpPut :
      HasIO io
   => (url : String)
   -> (auth : Maybe String)
   -> (body : String)
   -> io HttpResponse
httpPut url auth body = runCurlCmd (buildCurlMethod "PUT" url auth (Just body))

||| Perform a PATCH request with a JSON body.
public export
httpPatch :
      HasIO io
   => (url : String)
   -> (auth : Maybe String)
   -> (body : String)
   -> io HttpResponse
httpPatch url auth body = runCurlCmd (buildCurlMethod "PATCH" url auth (Just body))

||| Perform a DELETE request.
public export
httpDelete :
      HasIO io
   => (url : String)
   -> (auth : Maybe String)
   -> io HttpResponse
httpDelete url auth = runCurlCmd (buildCurlMethod "DELETE" url auth Nothing)
