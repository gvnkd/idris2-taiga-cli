module Network.HTTP.Error
import Derive.Prelude

%language ElabReflection

public export
data HttpError : Type -> Type where
  UnknownHost : HttpError e
  UnknownProtocol : String -> HttpError e
  ConnectionClosed : HttpError e
  SocketError : String -> HttpError e
  ContentLengthMismatch : Integer -> HttpError e
  MissingHeader : String -> HttpError e
  UnknownTransferEncoding : String -> HttpError e
  DecompressionError : String -> HttpError e
  OtherReason : e -> HttpError e

%runElab derive "HttpError" [Eq, Show]
