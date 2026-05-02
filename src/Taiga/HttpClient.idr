||| HTTP Client wrapper using the native Idris2 `http` library.
|||
||| Replaces curl subprocess with a native HTTP client supporting
||| TLS, connection pooling, and inline header extraction.
module Taiga.HttpClient

import Network.HTTP.Client as HC
import Network.HTTP.Message as HM
import Network.HTTP.Method as HM
import Network.HTTP.URL as HU
import Network.HTTP.Error as HE
import Network.HTTP.Status as HS
import Network.TLS as TLS
import Network.TLS.Certificate.System as TLS
import Utils.Streaming as US
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

||| Consume a byte stream and return the body as a String.
streamToString : US.Stream (US.Of Bits8) IO () -> IO (Either String String)
streamToString stream = do
  bytes <- US.toList_ stream
  pure (Right (bits8ListToString bytes))

||| Perform an HTTP request using the native http client.
httpRequest :
     {e : _}
  -> HC.HttpClient e
  -> HM.Method
  -> String
  -> List (String, String)
  -> Maybe String
  -> IO (Either String Response)
httpRequest client method urlStr headers mBody =
  case HU.url_from_string urlStr of
    Left err => pure (Left ("Invalid URL: " ++ urlStr ++ " (" ++ err ++ ")"))
    Right url => do
      let payload  := fromMaybe "" mBody
          headers' := case mBody of
                        Nothing => headers
                        Just _  => ("Content-Type", "application/json") :: headers
      let action : EitherT (HE.HttpError e) IO (HM.HttpResponse, List Bits8) = do
            (libResp, bodyStream) <- HC.request client method url headers' payload
            bytes <- US.toList_ bodyStream
            pure (libResp, bytes)
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
     {e : _}
  -> HC.HttpClient e
  -> String
  -> List (String, String)
  -> IO (Either String Response)
httpGet client url headers = httpRequest client HM.GET url headers Nothing

||| Convenience: POST request.
public export
httpPost :
     {e : _}
  -> HC.HttpClient e
  -> String
  -> List (String, String)
  -> String
  -> IO (Either String Response)
httpPost client url headers body = httpRequest client HM.POST url headers (Just body)

||| Convenience: PUT request.
public export
httpPut :
     {e : _}
  -> HC.HttpClient e
  -> String
  -> List (String, String)
  -> String
  -> IO (Either String Response)
httpPut client url headers body = httpRequest client HM.PUT url headers (Just body)

||| Convenience: PATCH request.
public export
httpPatch :
     {e : _}
  -> HC.HttpClient e
  -> String
  -> List (String, String)
  -> String
  -> IO (Either String Response)
httpPatch client url headers body = httpRequest client HM.PATCH url headers (Just body)

||| Convenience: DELETE request.
public export
httpDelete :
     {e : _}
  -> HC.HttpClient e
  -> String
  -> List (String, String)
  -> IO (Either String Response)
httpDelete client url headers = httpRequest client HM.DELETE url headers Nothing
