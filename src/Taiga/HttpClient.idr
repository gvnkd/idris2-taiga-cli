module Taiga.HttpClient
import Network.HTTP.Sync as HS
import Network.HTTP.Method as HM
import Network.HTTP.Message as MSG
import Network.HTTP.URL as HU
import Network.HTTP.Error as HE
import Network.HTTP.Status
import Utils.String as US
import Network.TLS.Verify
import Data.String
import Data.List
import Data.Maybe
import Control.Monad.Error.Either
import Control.Monad.Error.Interface

%language ElabReflection

public export
record Response where
  constructor MkResponse
  status : Bits16
  body : String
  headers : List (String, String)

bits8ListToString : List Bits8 -> String
bits8ListToString bs =
  pack (map (cast . (cast {to = Int})) bs)

formatHttpError : HttpError e -> String
formatHttpError UnknownHost =
  "Unknown host"
formatHttpError (UnknownProtocol p) =
  "Unknown protocol: " ++ p
formatHttpError ConnectionClosed =
  "Connection closed"
formatHttpError (SocketError s) =
  "Socket error: " ++ s
formatHttpError (ContentLengthMismatch n) =
  "Content length mismatch: " ++ show n
formatHttpError (MissingHeader h) =
  "Missing header: " ++ h
formatHttpError (UnknownTransferEncoding t) =
  "Unknown transfer encoding: " ++ t
formatHttpError (DecompressionError d) =
  "Decompression error: " ++ d
formatHttpError (OtherReason _) =
  "Other error"

httpRequestSync : HM.Method -> String -> List (String, String) -> Maybe String -> IO (Either String Response)
httpRequestSync method urlStr headers mBody =
  case HU.url_from_string urlStr of
    Left err => pure (Left ("Invalid URL: " ++ urlStr ++ " (" ++ err ++ ")"))
    Right url => do
                   let payload : _ = fromMaybe "" mBody
                   let headers' : _ = case mBody of
                                        Nothing => headers
                                        Just _ => ("Content-Type", "application/json") :: headers
                   let bodyBytes : _ = US.utf8_unpack payload
                   result <- (HS.requestSync {e = ()}) certificate_ignore_check method url headers' (length bodyBytes) bodyBytes
                   case result of
                     Left err => pure (Left ("HTTP request failed: " ++ formatHttpError err))
                     Right (libResp, bytes) => let statusNat = fst libResp.status_code in let statusNum = the Bits16 (cast statusNat) in let body = bits8ListToString bytes in pure (Right (MkResponse statusNum body libResp.headers))

public export
httpGet : String -> List (String, String) -> IO (Either String Response)
httpGet url headers =
  httpRequestSync HM.GET url headers Nothing

public export
httpPost : String -> List (String, String) -> String -> IO (Either String Response)
httpPost url headers body =
  httpRequestSync HM.POST url headers (Just body)

public export
httpPut : String -> List (String, String) -> String -> IO (Either String Response)
httpPut url headers body =
  httpRequestSync HM.PUT url headers (Just body)

public export
httpPatch : String -> List (String, String) -> String -> IO (Either String Response)
httpPatch url headers body =
  httpRequestSync HM.PATCH url headers (Just body)

public export
httpDelete : String -> List (String, String) -> IO (Either String Response)
httpDelete url headers =
  httpRequestSync HM.DELETE url headers Nothing
