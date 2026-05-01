||| API environment: base URL and auth token.
|||
||| Used as an auto-implicit parameter so that every Taiga endpoint
||| gets base URL and bearer token without repeating them in every
||| function signature.
module Taiga.Env

import Data.Bits
import Data.List
import Model.Common
import JSON.FromJSON
import JSON.ToJSON
import JSON.Encoder
import Taiga.Api

%language ElabReflection

||| URL-encode a string: spaces become %20, other special chars encoded.
public export
urlEncode : String -> String
urlEncode s = concat $ map encodeChar (unpack s)

  where isSafe : Char -> Bool
        isSafe c = any (== c) (unpack "-._~")

        hexDigit : Bits8 -> Char
        hexDigit n = case n of
          0  => '0'; 1  => '1'; 2  => '2'; 3  => '3'
          4  => '4'; 5  => '5'; 6  => '6'; 7  => '7'
          8  => '8'; 9  => '9'; 10 => 'A'; 11 => 'B'
          12 => 'C'; 13 => 'D'; 14 => 'E'; _  => 'F'

        hexDigitHex : Nat -> String
        hexDigitHex n = pack [hexDigit $ cast n]

        hex2 : Nat -> String
        hex2 n = hexDigitHex (n `div` 16) ++ hexDigitHex (n `mod` 16)

        encodeChar : Char -> String
        encodeChar c = if isAlphaNum c || isSafe c then pack [c] else "%" ++ hex2 (cast $ ord c)

||| Build a query string from key-value pairs with URL encoding.
public export
buildQueryString : List (String, String) -> String
buildQueryString [] = ""
buildQueryString kvs =
  let pairs := map (\(k, v) => urlEncode k ++ "=" ++ urlEncode v) kvs
   in "?" ++ concat (intersperse "&" pairs)

||| Omit a JSON object field when its value is `Nothing`.
||| Must be polymorphic in the encoder type `v` so it can be used
||| inside `ToJSON.toJSON` implementations (rank-2 type).
public export
omitNothing :
     ToJSON a
  => Encoder v
  => (key   : String)
  -> (value : Maybe a)
  -> Maybe (String, v)
omitNothing _ Nothing  = Nothing
omitNothing key (Just x) = Just (jpair key x)

||| Show a Nat64Id as its underlying numeric string.
public export
showId : Nat64Id -> String
showId n = show n.id

||| Build an API URL from base, path segments, and optional query params.
||| Eliminates all manual string concatenation in endpoint code.
public export
buildUrl : List String -> List (String, String) -> String -> String
buildUrl segments params base =
  let path   := concat $ map (\s => "/" ++ s) segments
      query  := buildQueryString params
   in base ++ path ++ query

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

||| Generic HTTP response handler: check status, then apply a function.
public export
expectWith :
     HasIO io
  => (resp : HttpResponse)
  -> (okStatus : Bits16)
  -> (errMsg : String)
  -> (HttpResponse -> Either String a)
  -> io (Either String a)
expectWith resp okStatus errMsg f =
  pure $ if resp.status.code == okStatus
           then f resp
           else Left $ errMsg ++ " failed with status "
                         ++ show resp.status.code

||| Parse an HTTP response as JSON on a specific status code.
public export
expectJson :
     FromJSON a
  => HasIO io
  => (resp : HttpResponse)
  -> (okStatus : Bits16)
  -> (errMsg : String)
  -> io (Either String a)
expectJson resp okStatus errMsg =
  expectWith resp okStatus errMsg (decodeEither . .body)

||| Check an HTTP response for a specific status code without parsing JSON.
public export
expectOk :
     HasIO io
  => (resp : HttpResponse)
  -> (okStatus : Bits16)
  -> (errMsg : String)
  -> io (Either String ())
expectOk resp okStatus errMsg =
  expectWith resp okStatus errMsg (const $ Right ())

||| Parse an HTTP response returning raw body on success.
public export
expectRaw :
     HasIO io
  => (resp : HttpResponse)
  -> (okStatus : Bits16)
  -> (errMsg : String)
  -> io (Either String String)
expectRaw resp okStatus errMsg =
  expectWith resp okStatus errMsg (Right . .body)
