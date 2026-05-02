||| HTTP Client wrapper using the native Idris2 `http` library (synchronous path).
|||
||| Uses `requestSync` for one-shot requests, bypassing connection pooling
||| and worker threads entirely.
module Taiga.HttpClient

import Network.HTTP.Client as HC
import Network.HTTP.Message as HM
import Network.HTTP.Method as HM
import Network.HTTP.URL as HU
import Network.HTTP.Error as HE
import Network.HTTP.Status as HS
import Network.TLS as TLS
import Network.TLS.Verify as TLS
import Data.String
import Data.List
import Data.Maybe
import Control.Monad.Error.Either
import Control.Monad.Error.Interface

%language ElabReflection

||| Simplified HTTP response type.
public export
record Response where
  constructor MkResponse
  status  : Bits16
  body    : String
  headers : List (String, String)

||| Convert a list of Bits8 to a String.
bits8ListToString : List Bits8 -> String
bits8ListToString bs = pack (map (cast . cast {to = Int}) bs)

||| Format an HttpError without requiring Show e.
formatHttpError : HttpError e -> String
formatHttpError UnknownHost                   = "Unknown host"
formatHttpError (UnknownProtocol p)           = "Unknown protocol: " ++ p
formatHttpError ConnectionClosed              = "Connection closed"
formatHttpError (SocketError s)               = "Socket error: " ++ s
formatHttpError (ContentLengthMismatch n)     = "Content length mismatch: " ++ show n
formatHttpError (MissingHeader h)             = "Missing header: " ++ h
formatHttpError (UnknownTransferEncoding t)   = "Unknown transfer encoding: " ++ t
formatHttpError (DecompressionError d)        = "Decompression error: " ++ d
formatHttpError (OtherReason _)               = "Other error"

||| Perform a synchronous HTTP request.
private
httpRequestSync :
     HM.Method
  -> String
  -> List (String, String)
  -> Maybe String
  -> IO (Either String Response)
httpRequestSync method urlStr headers mBody =
  case HU.url_from_string urlStr of
    Left err => pure (Left ("Invalid URL: " ++ urlStr ++ " (" ++ err ++ ")"))
    Right url => do
      let payload  := fromMaybe "" mBody
          headers' := case mBody of
                        Nothing => headers
                        Just _  => ("Content-Type", "application/json") :: headers
      let action : EitherT (HE.HttpError ()) IO (HM.HttpResponse, List Bits8) =
            HC.requestSync TLS.certificate_ignore_check method url headers' payload
      result <- runEitherT action
      case result of
        Left err => pure (Left ("HTTP request failed: " ++ formatHttpError err))
        Right (libResp, bytes) =>
          let statusNat := fst libResp.status_code
              statusNum := the Bits16 (cast statusNat)
              body      := bits8ListToString bytes
           in pure (Right (MkResponse statusNum body libResp.headers))

||| Convenience: GET request.
public export
httpGet :
     String
  -> List (String, String)
  -> IO (Either String Response)
httpGet url headers = httpRequestSync HM.GET url headers Nothing

||| Convenience: POST request with a JSON body.
public export
httpPost :
     String
  -> List (String, String)
  -> String
  -> IO (Either String Response)
httpPost url headers body = httpRequestSync HM.POST url headers (Just body)

||| Convenience: PUT request with a JSON body.
public export
httpPut :
     String
  -> List (String, String)
  -> String
  -> IO (Either String Response)
httpPut url headers body = httpRequestSync HM.PUT url headers (Just body)

||| Convenience: PATCH request with a JSON body.
public export
httpPatch :
     String
  -> List (String, String)
  -> String
  -> IO (Either String Response)
httpPatch url headers body = httpRequestSync HM.PATCH url headers (Just body)

||| Convenience: DELETE request.
public export
httpDelete :
     String
  -> List (String, String)
  -> IO (Either String Response)
httpDelete url headers = httpRequestSync HM.DELETE url headers Nothing
