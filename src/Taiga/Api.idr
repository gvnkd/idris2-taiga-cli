||| HTTP client wrapper — now using the native Idris2 `http` library.
|||
||| Provides typed GET / POST / PUT / PATCH / DELETE helpers
||| that handle JSON bodies and Bearer-token authentication.
module Taiga.Api

import JSON.Derive
import System
import Data.String
import Data.List
import Data.Maybe
import Taiga.HttpClient

%language ElabReflection

||| HTTP status code.
public export
record StatusCode where
  constructor MkStatusCode
  code : Bits16

%runElab derive "StatusCode" [Show,Eq]

||| Parsed pagination metadata from response headers.
public export
record PaginationMeta where
  constructor MkPaginationMeta
  totalCount  : Maybe Bits64
  currentPage : Maybe Bits32
  nextUrl     : Maybe String
  prevUrl     : Maybe String

||| Result of an HTTP request: status code, response body, and headers.
public export
record HttpResponse where
  constructor MkHttpResponse
  status  : StatusCode
  body    : String
  headers : List (String, String)

%runElab derive "HttpResponse" [Show]

||| Parse a header line into (key, value) pair.
parseHeaderLine : String -> Maybe (String, String)
parseHeaderLine line =
  case forget (split (== ':') line) of
    key :: valueParts =>
      let val := trim (concat (intersperse ":" valueParts))
       in Just (trim (toLower key), val)
    _ => Nothing

||| Try to parse a String into a Bits64.
private
parseBits64 : String -> Maybe Bits64
parseBits64 s =
  case parseInteger {a = Integer} s of
    Just n => if n >= 0 then Just (cast n) else Nothing
    Nothing => Nothing

||| Try to parse a String into a Bits32.
private
parseBits32 : String -> Maybe Bits32
parseBits32 s =
  case parseInteger {a = Integer} s of
    Just n => if n >= 0 then Just (cast n) else Nothing
    Nothing => Nothing

||| Extract pagination metadata from response headers.
public export
extractPagination : HttpResponse -> PaginationMeta
extractPagination resp =
  MkPaginationMeta
    (join $ parseBits64 <$> lookup "x-pagination-count" resp.headers)
    (join $ parseBits32 <$> lookup "x-pagination-current" resp.headers)
    (lookup "x-pagination-next" resp.headers)
    (lookup "x-pagination-prev" resp.headers)

||| Convert library Response to our HttpResponse.
private
fromLibResponse : Taiga.HttpClient.Response -> HttpResponse
fromLibResponse r = MkHttpResponse (MkStatusCode r.status) r.body r.headers

||| Check if a response has HTML content type.
private
isHtmlResponse : HttpResponse -> Bool
isHtmlResponse resp =
  case lookup "content-type" resp.headers of
    Nothing => False
    Just ct => isInfixOf "text/html" (toLower ct)

||| Check if status code indicates a server error (5xx).
private
isServerError : HttpResponse -> Bool
isServerError resp =
  let code := resp.status.code in
  code >= 500 && code < 600

||| If the response is problematic (HTML error page or 5xx), return an error.
||| Returns Nothing if the response looks fine for JSON parsing.
private
checkResponse : HttpResponse -> Maybe String
checkResponse resp =
  let status_code := resp.status.code in
    if isHtmlResponse resp then
      Just $ "Server returned HTML (status " ++ show status_code ++ "). Likely an error page."
     else if isServerError resp then
       Just $ "Server error: status " ++ show status_code
        else Nothing

||| Build the Authorization header.
private
buildAuthHeader : Maybe String -> List (String, String)
buildAuthHeader Nothing    = []
buildAuthHeader (Just tok) = [("Authorization", "Bearer " ++ tok)]

||| Perform a GET request.
public export
httpGet :
     HasIO io
  => (url : String)
  -> (auth : Maybe String)
  -> io HttpResponse
httpGet url auth = do
  result <- liftIO $ Taiga.HttpClient.httpGet url (buildAuthHeader auth)
  case result of
    Left err  => pure (MkHttpResponse (MkStatusCode 0) ("HTTP error: " ++ err) [])
    Right resp =>
      let response := fromLibResponse resp in
        case checkResponse response of
          Just errMsg => pure $ MkHttpResponse (MkStatusCode 0) errMsg []
          Nothing     => pure response

||| Perform a POST request with a JSON body.
public export
httpPost :
      HasIO io
   => (url : String)
  -> (auth : Maybe String)
  -> (body : String)
  -> io HttpResponse

public export
httpPut :
      HasIO io
   => (url : String)
  -> (auth : Maybe String)
  -> (body : String)
  -> io HttpResponse

public export
httpPatch :
      HasIO io
   => (url : String)
  -> (auth : Maybe String)
  -> (body : String)
  -> io HttpResponse

public export
httpDelete :
      HasIO io
   => (url : String)
  -> (auth : Maybe String)
  -> io HttpResponse

httpPost url auth body = do
  result <- liftIO $ Taiga.HttpClient.httpPost url (buildAuthHeader auth) body
  case result of
    Left err  => pure (MkHttpResponse (MkStatusCode 0) ("HTTP error: " ++ err) [])
    Right resp =>
      let response := fromLibResponse resp in
        case checkResponse response of
          Just errMsg => pure $ MkHttpResponse (MkStatusCode 0) errMsg []
          Nothing     => pure response

httpPut url auth body = do
  result <- liftIO $ Taiga.HttpClient.httpPut url (buildAuthHeader auth) body
  case result of
    Left err  => pure (MkHttpResponse (MkStatusCode 0) ("HTTP error: " ++ err) [])
    Right resp =>
      let response := fromLibResponse resp in
        case checkResponse response of
          Just errMsg => pure $ MkHttpResponse (MkStatusCode 0) errMsg []
          Nothing     => pure response

httpPatch url auth body = do
  result <- liftIO $ Taiga.HttpClient.httpPatch url (buildAuthHeader auth) body
  case result of
    Left err  => pure (MkHttpResponse (MkStatusCode 0) ("HTTP error: " ++ err) [])
    Right resp =>
      let response := fromLibResponse resp in
        case checkResponse response of
          Just errMsg => pure $ MkHttpResponse (MkStatusCode 0) errMsg []
          Nothing     => pure response

httpDelete url auth = do
  result <- liftIO $ Taiga.HttpClient.httpDelete url (buildAuthHeader auth)
  case result of
    Left err  => pure (MkHttpResponse (MkStatusCode 0) ("HTTP error: " ++ err) [])
    Right resp =>
      let response := fromLibResponse resp in
        case checkResponse response of
          Just errMsg => pure $ MkHttpResponse (MkStatusCode 0) errMsg []
          Nothing     => pure response
