module State.AuthStore
import JSON.Derive
import JSON.ToJSON
import JSON.FromJSON
import Model.Auth
import Taiga.Auth
import Taiga.Env
import State.File
import State.State
import Control.AppM
import Control.Monad.Error.Either

%language ElabReflection

public export
instanceHash : String -> String
instanceHash base =
  pack $ map sanitizeChar (unpack base)
  where
    sanitizeChar : Char -> Char
    sanitizeChar c =
      if isAlphaNum c || c == '.' || c == '-'
        then c
        else
          '_'

public export
loadToken : String -> IO (Maybe Token)
loadToken baseUrl = do
  let hash : _ = instanceHash baseUrl
  load GlobalAuthStore hash

public export
saveToken : String -> Token -> IO ()
saveToken baseUrl tok = do
  let hash : _ = instanceHash baseUrl
  save GlobalAuthStore hash tok

public export
removeToken : String -> IO ()
removeToken baseUrl = do
  let hash : _ = instanceHash baseUrl
  removeFile' GlobalAuthStore hash

public export
authenticateIO : String -> Credentials -> IO (Either String Token)
authenticateIO baseUrl creds = do
  result <- login baseUrl creds
  case result of
    Left err => pure $ Left err
    Right tok => do
                   saveToken baseUrl tok
                   pure $ Right tok

public export
resolveAuth : AppM ApiEnv
resolveAuth = do
  st <- liftIOEither loadState
  tok_m <- liftRawIO $ loadToken st.base_url
  case tok_m of
    Nothing => appFail "Not authenticated. Run 'taiga-cli login'."
    Just tok => pure $ buildApiEnvWithToken st.base_url tok.auth_token

public export
tryRefresh : String -> Token -> IO (Either String Token)
tryRefresh baseUrl tok =
  case tok.refresh of
    Nothing => pure $ Left "No refresh token available"
    Just rtok => do
                   result <- refreshToken baseUrl rtok
                   case result of
                     Left err => pure $ Left err
                     Right tok' => do
                                     saveToken baseUrl tok'
                                     pure $ Right tok'
