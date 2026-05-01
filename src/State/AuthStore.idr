||| Token Lifecycle Management (Global Storage).
|||
||| Handles token persistence in the GLOBAL directory, expiration
||| detection, and auto-refresh.  Tokens are keyed by an instance hash
||| derived from the base URL.
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

||| Sanitize a base URL into a safe filename by replacing special
||| characters with underscores.
public export
instanceHash : String -> String
instanceHash base =
  pack $ map sanitizeChar (unpack base)
  where
    sanitizeChar : Char -> Char
    sanitizeChar c =
      if isAlphaNum c || c == '.' || c == '-'
        then c
        else '_'

||| Load a token for a given instance.  Returns Nothing if not
||| authenticated.
public export
loadToken : String -> IO (Maybe Token)
loadToken baseUrl = do
  let hash := instanceHash baseUrl
  load GlobalAuthStore hash

||| Save a token for a given instance.
public export
saveToken : String -> Token -> IO ()
saveToken baseUrl tok = do
  let hash := instanceHash baseUrl
  save GlobalAuthStore hash tok

||| Remove a token for a given instance (logout).
public export
removeToken : String -> IO ()
removeToken baseUrl = do
  let hash := instanceHash baseUrl
  removeFile' GlobalAuthStore hash

||| Authenticate with credentials and persist the token globally.
public export
authenticateIO : String -> Credentials -> IO (Either String Token)
authenticateIO baseUrl creds = do
  result <- login baseUrl creds
  case result of
    Left err  => pure $ Left err
    Right tok => do
      saveToken baseUrl tok
      pure $ Right tok

||| Resolve auth for a workspace: load state, look up token, build
||| ApiEnv.  Returns the ApiEnv ready for API calls.
public export
resolveAuth : AppM ApiEnv
resolveAuth = do
  st <- liftIOEither loadState
  tok_m <- liftRawIO $ loadToken st.base_url
  case tok_m of
    Nothing   => appFail "Not authenticated. Run 'taiga-cli login'."
    Just tok  => pure $ buildApiEnvWithToken st.base_url tok.auth_token

||| Attempt to refresh a token using the stored refresh token.
||| Returns new token on success, original on failure.
public export
tryRefresh : String -> Token -> IO (Either String Token)
tryRefresh baseUrl tok =
  case tok.refresh of
    Nothing    => pure $ Left "No refresh token available"
    Just rtok  => do
      result <- refreshToken baseUrl rtok
      case result of
        Left err   => pure $ Left err
        Right tok' => do
          saveToken baseUrl tok'
          pure $ Right tok'
