module Taiga.Env
import Data.Bits
import Data.List
import Model.Common
import JSON.FromJSON
import JSON.ToJSON
import JSON.Encoder
import Taiga.Api

%language ElabReflection

public export
urlEncode : String -> String
urlEncode s =
  concatMap encodeChar (unpack s)
  where
    isSafe : Char -> Bool
    isSafe c =
      any (== c) (unpack "-._~")
    hexDigit : Bits8 -> Char
    hexDigit n =
      case n of
        0 => '0'
        1 => '1'
        2 => '2'
        3 => '3'
        4 => '4'
        5 => '5'
        6 => '6'
        7 => '7'
        8 => '8'
        9 => '9'
        10 => 'A'
        11 => 'B'
        12 => 'C'
        13 => 'D'
        14 => 'E'
        _ => 'F'
    hexDigitHex : Nat -> String
    hexDigitHex n =
      pack [hexDigit $ cast n]
    hex2 : Nat -> String
    hex2 n =
      hexDigitHex (n `div` 16) ++ hexDigitHex (n `mod` 16)
    encodeChar : Char -> String
    encodeChar c =
      if isAlphaNum c || isSafe c
        then pack [c]
        else
          "%" ++ hex2 (cast $ ord c)

public export
buildQueryString : List (String, String) -> String
buildQueryString [] =
  ""
buildQueryString kvs =
  let pairs = map (\(k, v) => urlEncode k ++ "=" ++ urlEncode v) kvs in "?" ++ concat (intersperse "&" pairs)

public export
omitNothing : ToJSON a => Encoder v => (key : String) -> (value : Maybe a) -> Maybe (String, v)
omitNothing _ Nothing =
  Nothing
omitNothing key (Just x) =
  Just (jpair key x)

public export
showId : Nat64Id -> String
showId n =
  show n.id

public export
buildUrl : List String -> List (String, String) -> String -> String
buildUrl segments params base =
  let path = concatMap (\s => "/" ++ s) segments in let query = buildQueryString params in base ++ path ++ query

public export
parseBits64 : String -> Bits64
parseBits64 =
  cast

public export
record ApiEnv where
  constructor MkApiEnv
  base : String
  token : String

public export
authGet : HasIO io => (env : ApiEnv) -> (url : String) -> io HttpResponse
authGet env url =
  httpGet url (Just env.token)

public export
authPost : HasIO io => (env : ApiEnv) -> (url : String) -> (body : String) -> io HttpResponse
authPost env url body =
  httpPost url (Just env.token) body

public export
authPut : HasIO io => (env : ApiEnv) -> (url : String) -> (body : String) -> io HttpResponse
authPut env url body =
  httpPut url (Just env.token) body

public export
authDelete : HasIO io => (env : ApiEnv) -> (url : String) -> io HttpResponse
authDelete env url =
  httpDelete url (Just env.token)

public export
authPatch : HasIO io => (env : ApiEnv) -> (url : String) -> (body : String) -> io HttpResponse
authPatch env url body =
  httpPatch url (Just env.token) body

fmtError : (errMsg : String) -> (code : Bits16) -> String
fmtError msg 401 =
  "Authentication failed."
fmtError msg 403 =
  "Permission denied."
fmtError msg 404 =
  msg ++ " not found"
fmtError msg code =
  msg ++ ": status " ++ show code

public export
expectWith : HasIO io => (resp : HttpResponse) -> (okStatus : Bits16) -> (errMsg : String) -> (HttpResponse -> Either String a) -> io (Either String a)
expectWith resp okStatus errMsg f =
  pure $ (if resp.status.code == okStatus
            then f resp
              else
                Left $ fmtError errMsg resp.status.code)

public export
expectJson : FromJSON a => HasIO io => (resp : HttpResponse) -> (okStatus : Bits16) -> (errMsg : String) -> io (Either String a)
expectJson resp okStatus errMsg =
  expectWith resp okStatus errMsg (decodeEither . (.body))

public export
expectJsonWithMeta : FromJSON a => HasIO io => (resp : HttpResponse) -> (okStatus : Bits16) -> (errMsg : String) -> io (Either String (a, PaginationMeta))
expectJsonWithMeta resp okStatus errMsg =
  expectWith resp okStatus errMsg $ (\r => case decodeEither r.body of
                                             Left err => Left err
                                             Right val => Right (val, extractPagination r))

public export
expectOk : HasIO io => (resp : HttpResponse) -> (okStatus : Bits16) -> (errMsg : String) -> io (Either String ())
expectOk resp okStatus errMsg =
  expectWith resp okStatus errMsg (const $ Right ())

public export
expectRaw : HasIO io => (resp : HttpResponse) -> (okStatus : Bits16) -> (errMsg : String) -> io (Either String String)
expectRaw resp okStatus errMsg =
  expectWith resp okStatus errMsg (Right . (.body))
