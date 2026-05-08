module Network.HTTP.Sync
import Network.Socket
import Network.HTTP.Error
import Network.HTTP.Protocol
import Network.HTTP.Message
import Network.HTTP.Header
import Network.HTTP.Method
import Network.HTTP.URL
import Network.HTTP.Path
import Network.HTTP.Status
import Network.TLS
import Network.TLS.Signature
import Utils.Bytes
import Utils.String
import Utils.Num
import Data.String
import Data.Nat
import Data.List
import Data.List1
import Data.Maybe
import Data.Fin
import Control.Monad.Error.Either

recvLine : Socket -> IO (Either String String)
recvLine sock =
  go []
  where
    go : List Bits8 -> IO (Either String String)
    go acc = do
      result <- recvBytes sock 1
      case result of
        Left err => pure (Left "recvLine failed: \{show err}")
        Right [] => pure (Left "recvLine: connection closed unexpectedly")
        Right [c] => do
                       let acc' : _ = acc ++ [c]
                       if c == 10
                         then do
                                let withoutCr : _ = case reverse acc' of
                                                      10 :: 13 :: rest => reverse rest
                                                      10 :: rest => reverse rest
                                                      _ => acc'
                                case utf8_pack withoutCr of
                                  Just s => pure (Right s)
                                  Nothing => pure (Left "recvLine: invalid UTF-8")
                           else
                             go acc'
        Right _ => pure (Left "recvLine: unexpected multi-byte recv")

recvHeaders : Socket -> IO (Either String String)
recvHeaders sock =
  go ""
  where
    go : String -> IO (Either String String)
    go acc = do
      result <- recvLine sock
      case result of
        Left err => pure (Left err)
        Right line => if line == ""
                        then pure (Right acc)
                          else
                            go (acc ++ line ++ "\n")

sendAll : Socket -> List Bits8 -> IO (Either String ())
sendAll sock [] =
  pure (Right ())
sendAll sock bs = do
  result <- sendBytes sock bs
  case result of
    Left err => pure (Left "sendAll failed: \{show err}")
    Right n => let sent = (cast {to = Integer}) n in let rest = drop (cast sent) bs in if sent == 0
                                                                                         then pure (Left "sendAll: sent 0 bytes")
                                                                                           else
                                                                                             sendAll sock rest

recvFixed : Socket -> Integer -> IO (Either String (List Bits8))
recvFixed sock remaining =
  go remaining []
  where
    go : Integer -> List Bits8 -> IO (Either String (List Bits8))
    go 0 acc =
      pure (Right acc)
    go n acc = do
      let toRead : _ = if n > 65536 then 65536 else (cast {to = Int}) n
      result <- recvBytes sock toRead
      case result of
        Left err => pure (Left "recvFixed failed: \{show err}")
        Right bs => if length bs == 0
                      then pure (Left "recvFixed: connection closed before reading all bytes")
                        else
                          go (n - cast (length bs)) (acc ++ bs)

recvChunked : Socket -> IO (Either String (List Bits8))
recvChunked sock =
  go []
  where
    go : List Bits8 -> IO (Either String (List Bits8))
    go acc = do
      result <- recvLine sock
      case result of
        Left err => pure (Left err)
        Right line => case stringToNat (the (Fin 36) 16) (toLower line) of
                        Just Z => do
                                    emptyLine <- recvLine sock
                                    case emptyLine of
                                      Left err => pure (Left err)
                                      Right _ => pure (Right acc)
                        Just len => do
                                      result2 <- recvFixed sock (cast len)
                                      case result2 of
                                        Left err => pure (Left err)
                                        Right chunk => do
                                                         trailing <- recvLine sock
                                                         case trailing of
                                                           Left err => pure (Left err)
                                                           Right _ => go (acc ++ chunk)
                        Nothing => pure (Left "recvChunked: invalid chunk size: \{line}")

export
requestSync : {e : _} -> (cert_checker : String -> CertificateCheck IO) -> Method -> URL -> List (String, String) -> (length : Nat) -> (input : List Bits8) -> IO (Either (HttpError e) (HttpResponse, List Bits8))
requestSync cert_checker method url headers payload_size payload = do
  let Just protocol = protocol_from_str url.protocol
  | Nothing => pure (Left (UnknownProtocol url.protocol))
  let headers' : _ = ("Host", hostname_string url.host) :: ("User-Agent", "idris2-http") :: ("Content-Length", show payload_size) :: headers
  let message : _ = MkRawHttpMessage method (show url.path ++ url.extensions) headers'
  let requestBytes : _ = utf8_unpack (serialize_http_message message) ++ payload
  let hostname : _ = url.host
  let hostname_str : _ = hostname_string hostname
  let port : _ = case hostname.port of
                   Just p => p
                   Nothing => protocol_port_number protocol
  result <- socket AF_INET Stream 0
  case result of
    Left err => pure (Left (SocketError "socket creation failed: \{show err}"))
    Right sock => do
                    connResult <- connect sock (Hostname hostname.domain) (cast port)
                    case connResult of
                      0 => do
                             sendResult <- sendAll sock requestBytes
                             case sendResult of
                               Left err => do
                                             close sock
                                             pure (Left (SocketError err))
                               Right () => do
                                             headerResult <- recvHeaders sock
                                             case headerResult of
                                               Left err => do
                                                             close sock
                                                             pure (Left (SocketError err))
                                               Right headerBlock => do
                                                                      let headerBlock' : _ = headerBlock ++ "\n"
                                                                      case deserialize_http_response headerBlock' of
                                                                        Left err => do
                                                                                      close sock
                                                                                      pure (Left (SocketError "failed to parse response: \{err}"))
                                                                        Right response => do
                                                                                            let encodings : _ = join $ toList (forget <$> lookup_header response.headers TransferEncoding)
                                                                                            bodyResult <- if elem Chunked encodings
                                                                                                            then recvChunked sock
                                                                                                              else
                                                                                                                case lookup_header response.headers ContentLength of
                                                                                                                  Just cl => recvFixed sock cl
                                                                                                                  Nothing => do
                                                                                                                               allResult <- recvAllBytes sock
                                                                                                                               pure $ (case allResult of
                                                                                                                                         Left err => Left (show err)
                                                                                                                                         Right bs => Right bs)
                                                                                            close sock
                                                                                            case bodyResult of
                                                                                              Left err => pure (Left (SocketError err))
                                                                                              Right bytes => pure (Right (response, bytes))
                      err => do
                               close sock
                               pure (Left (SocketError "connect failed: \{show err}"))
-- Send request
-- Read response headers
-- Read body
