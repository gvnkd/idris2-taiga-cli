# Stateful Taiga CLI — Functional Patterns & Code Samples

## ⚠️ SECURITY NOTE

Throughout these samples, note that `AppSt` has no auth fields. Authentication is always resolved at runtime via `AuthStore.resolveAuth()`, which looks up the token from `~/.local/share/taiga-cli/tokens/` using the instance hash of the base URL. No sample below stores credentials in workspace state.

---

## Core Pattern: Two-Phase State Load (Workspace + Auth)

Each invocation loads workspace state from `./taiga/state.json` and auth tokens from `~/.local/share/taiga-cli/tokens/<hash>.json` independently. The two are composed at runtime to produce an `ApiEnv`.

### Loading Workspace State (No Secrets)

All state operations return `IO (Either String _)` — no silent crashes, consistent with the unified error-handling layer:

```idris
module State.State

||| Load workspace state; returns Left with message if not initialized.
loadState : IO (Either String AppSt)
loadState = do
  result <- load WorkspaceStore "state"
  case result of
    Just st  => pure $ Right st
    Nothing  => pure $ Left "No state found. Run 'taiga-cli init' first."

||| Save workspace state to disk (no secrets). Returns Left on I/O error.
saveState : AppSt -> IO (Either String ())
saveState st = 
  case save WorkspaceStore "state" st of
    Ok _   => pure $ Right ()
    Err e  => pure $ Left ("Failed to save state: " ++ show e)

||| Build an ApiEnv from workspace state + a resolved token.
||| The token comes from AuthStore, never from AppSt.
buildApiEnvWithToken : Token -> AppSt -> ApiEnv
buildApiEnvWithToken tok st = MkApiEnv st.base_url tok.auth_token

||| Full auth resolution: load state, look up token, build ApiEnv.
||| Returns the pair (ApiEnv, AppSt) so callers don't reload state.
resolveApiEnv : IO (Either String (ApiEnv, AppSt))
resolveApiEnv = do
  st_e <- loadState
  case st_e of
    Left err   => pure $ Left err
    Right st'  => do
      token_e <- loadToken st'.base_url
      case token_e of
        Nothing   => pure $ Left "Not authenticated. Run 'taiga-cli login'."
        Just tok  => 
           let env := buildApiEnvWithToken tok st'
            in pure $ Right (env, st')
```

**Key design**: `resolveApiEnv` returns the loaded state alongside the environment. This eliminates redundant disk I/O: every handler gets both in one call without reloading.

## GADT: Action-to-Result Mapping

The `Action` data type encodes what the user wants. Each action handler returns a uniform result type that the output layer can format either as text or JSON. Using `JSON.Value` for payload avoids double-serialization (no need to embed a JSON string inside another JSON envelope).

### Unified Result Type

```idris
module CLI.Subcommand

||| A unified result that carries both human-readable content and structured data.
record CmdResult where
  constructor MkCmdResult
  status   : Bits8               -- HTTP-like status: 0=ok, 1=error, 2=info
  message  : String              -- Human-readable summary line
  payload  : JSON.Value          -- Structured data for machine consumers

%runElab derive "CmdResult" [Show, ToJSON]

||| Convenience constructors.
cmdOk     : (ToJSON a) => String -> a -> CmdResult      -- msg, structured value
cmdOk msg val = MkCmdResult 0 msg (toJSON val)

cmdError  : String -> CmdResult                         -- error message
cmdError err = MkCmdResult 1 err JSON.Null

cmdInfo   : String -> CmdResult                         -- info message  
cmdInfo msg = MkCmdResult 2 msg JSON.Null
```

### Example: `task list` Handler (With Auth Resolution)

No monad-transformers used. Plain IO + Either, consistent with the rest of the codebase:

```idris
||| Handler for ActTaskList.
handleTaskList : Maybe String -> IO (Either String CmdResult)
handleTaskList maybeStatus = do
  ||| Resolve auth + env in one shot via AuthStore. No redundant state reload:
  ||| resolveApiEnv returns the loaded AppSt alongside ApiEnv, so we have both.
  case resolveApiEnv of
    Left err   => pure $ Left ("Auth failed: " ++ err)
    Right (env, st) => do
      case st.active_project of
        Nothing => pure $ Left "No active project set. Run 'taiga-cli project set <slug>' first."
        Just projId => do
          result <- listTasks @{env} (show projId.id) Nothing maybeStatus Nothing
          case result of
            Left err  => pure $ Left ("Failed to list tasks: " ++ err)
            Right tasks => 
               pure $ Right $ cmdOk ("Found " ++ show (length tasks) ++ " tasks") tasks
```

### Example: `project set` Handler

```idris
||| Handler for ActProjectSet.
handleProjectSet : String -> IO (Either String CmdResult)
handleProjectSet ident = do
  case resolveApiEnv of
    Left err => pure $ Left ("Auth failed: " ++ err)
    Right (env, st) => do
      ||| Try to resolve as a slug first, then as an ID.
      result <- getProjectBySlug @{env} (MkSlug ident)
      case result of
        Left _ => 
          ||| Slug failed, try parsing as numeric ID.
          case decodeEither (pack ident) of
            Left _   => pure $ Left ("Cannot resolve project: " ++ ident)
            Right id => do
              proj <- getProjectById @{env} id
              case proj of
                Left err  => pure $ Left ("Failed to get project: " ++ err)
                Right p  => do
                  setActiveProject (MkNat64Id id)
                  saveProjectCache p
                  pure $ Right $ cmdOk ("Active project set to: " ++ p.name) p
        Right proj => do
          setActiveProject proj.id
          saveProjectCache proj.contents
          pure $ Right $ cmdOk ("Active project set to: " ++ proj.contents.name) proj.contents
```

### Example: `login` Handler (Writes to Global Auth Store Only)

```idris
||| Handler for ActLogin. Writes token to ~/.local/share/taiga-cli/tokens/,
||| NOT to ./taiga/. Also sets base_url in workspace state if not initialized.
handleLogin : Credentials -> IO (Either String CmdResult)
handleLogin creds = do
  st <- case loadState of
           Left err => pure $ Left err
           Right s  => pure $ Right s
  case st of
    Left _     => pure $ Left "Not initialized. Run 'taiga-cli init' first."
    Right st'  => 
      case authenticate st'.base_url creds of          -- AuthStore.authenticate
        Left err  => pure $ Left ("Login failed: " ++ err)
        Right tok => pure $ Right $ cmdOk "Authenticated successfully" (Just ())

||| Note: authenticate() internally calls saveToken() which targets
||| GlobalAuthStore — structurally impossible to write to workspace dir.
```

### Example: `init` Handler

```idris
||| Handler for ActInit.
handleInit : Maybe String -> IO (Either String CmdResult)   -- Nothing→default base_url
handleInit maybeBaseUrl = do
  let baseUrl := case maybeBaseUrl of
                    Just u => u
                    Nothing -> "http://localhost:8000"

  ensureDir WorkspaceStore
    
  ||| Create workspace state (no secrets).
  let st := MkAppSt { base_url       = baseUrl
                    , active_project = Nothing
                    , project_cache  = Nothing }
  
  saveState st
  pure $ Right $ cmdInfo ("Initialized taiga state in ./taiga/ (base: " ++ baseUrl ++ ")")

||| Global config is created lazily on first access, not during init.
||| This keeps init focused solely on workspace setup.
```

## Output Formatting

The output layer renders a `CmdResult` either as formatted text or raw JSON, depending on the `--json` flag.

```idris
module CLI.Output

||| Format a CmdResult for display.
renderCmdResult : OutputFormat -> CmdResult -> String
renderCmdResult JsonFmt _ cr = encode cr
renderCmdResult TextFmt _  cr = 
  case cr.status of
    0 => "[OK]   " ++ cr.message
    1 => "[ERR]  " ++ cr.message
    2 => "[INFO] " ++ cr.message
    _ => cr.message

||| For tabular data (task lists, project lists), we provide specialized 
||| text renderers that produce aligned columns.
renderTaskListText : List TaskSummary -> String
renderTaskListText tasks = go tasks ""
  where
    go : List TaskSummary -> String -> String
    go [] acc        = reverse acc
    go (t :: ts) acc = 
       let line := show t.ref ++ "  " ++ t.subject ++ "\n"
        in go ts (acc ++ line)
```

## Functional Patterns Used Throughout

### Functor / Applicative Chaining for State Access

All state operations return `IO (Either String _)`, making it easy to chain with functors:

```idris
||| Get the active project ID from state, with a default error message.
getActiveProject : IO (Either String Nat64Id)
getActiveProject = do
  st_e <- loadState
  pure $ case st_e of
    Left err     => Left err
    Right st' => 
      case st'.active_project of
        Nothing => Left "No active project set"
        Just id => Right id

||| Alternatively with applicative style (preferred):
getActiveProject' : IO (Either String Nat64Id)
getActiveProject' = fmap checkProject loadState
  where
    checkProject : Either String AppSt -> Either String Nat64Id
    checkProject (Left err)     = Left err
    checkProject (Right st') = 
      case st'.active_project of
        Nothing => Left "No active project set"
        Just id => Right id
```

### Parameters Block for Shared Context

All action handlers operate within the shared context of loaded state and API environment. We use `parameters` with explicit implicit args to avoid threading them manually:

```idris
parameters {env : ApiEnv}
           {st  : AppSt}

  ||| Within this block, all functions receive env and st as implicit arguments.
  
  listProjectTasks : Maybe String -> IO (Either String (List TaskSummary))
  listProjectTasks maybeStatus = 
    case st.active_project of
      Nothing => pure $ Left "No active project"
      Just pid => listTasks @{env} (show pid.id) Nothing maybeStatus Nothing
  
  getActiveProjectDetails : IO (Either String Project)
  getActiveProjectDetails = 
    case st.project_cache of
      Just p  => pure $ Right p
      Nothing => 
        case st.active_project of
          Nothing => pure $ Left "No active project"
          Just id => getProjectById @{env} id

||| Callers pass env and st explicitly:
runWithCtx : (ApiEnv, AppSt) -> ({auto env' : ApiEnv}, {st' : AppSt}) 
                 -> IO (Either String a)
                 -> IO (Either String a)
runWithCtx (e, s) action = do
  let resolved := MkResolved e s   -- bundle context into implicit provider
   in action @{resolved.env'} @{resolved.st}
```

### Map-Based Table Rendering

No mutable state or recursive accumulators — just `map` over structured data:

```idris
||| Render a list of items as a text table using map and intercalate.
renderTable : (a -> List String)   -- column extractor
           -> List a 
           -> String
renderTable cols rows = 
  let header := join "\t" (cols $ headDefault defaultRow rows)
      lines  := map (\r => join "\t" $ cols r) rows
      all    := header :: lines
   in intercalate "\n" all
  where
    defaultRow : a              -- implementation dependent
    join       : List String -> String
    
||| Usage:
taskColumns : TaskSummary -> List String
taskColumns t = [ show t.ref.id, t.subject ]

renderTaskTable : List TaskSummary -> String
renderTaskTable = renderTable taskColumns
```

## Auto-Implicit ApiEnv Pattern (Preserved from Existing Codebase)

All Taiga API modules already use `parameters {auto env : ApiEnv}`. This pattern is preserved and extended throughout the new code:

```idris
||| Every Taiga module looks like this:
parameters {auto env : ApiEnv}

  listTasks : (project     : Maybe String)
            -> (status      : Maybe String)
            -> (page        : Maybe Nat)
            -> (page_size   : Maybe Nat)
            -> IO (Either String (List TaskSummary))
  listTasks project status page page_size = 
     let qs := buildQueryString [(project, "project")
                                ,(fmap (\s => s ++ ":" ++ show status), status)
                                ,(...)]
      in apiGet ("/tasks" <> qs)

||| The new state layer constructs env and passes it via auto-implicit.
||| No lifting through monad-transformers needed — just explicit context threading.
```

## Error Handling Pattern

All errors flow through `Either String a` at the API boundary, then are wrapped into `CmdResult` at the CLI boundary:

```idris
||| The error handling funnel (unified across all layers):
|||
||| Taiga/*.idr     : Either String a              (raw HTTP errors)
|||       ↓
||| State.AuthStore : Either String (ApiEnv, AppSt)  (auth resolution + state)
|||       ↓  
||| CLI.Subcommand  : CmdResult                    (status code + message + payload)  
|||       ↓
||| CLI.Output      : String                       (formatted text or JSON for stdout)

apiCallToCmdResult : ToJSON a => IO (Either String a) -> IO (Either String CmdResult)
apiCallToCmdResult apiAction = do
  result <- apiAction
  case result of
    Left err   => pure $ Right $ cmdError err
    Right val  => pure $ Right $ cmdOk "success" val
```

## Security Invariant: Type-Level Separation

The key security property is enforced at the type level:

```idris
||| AppSt has no Token field — it's structurally impossible to leak credentials.
record AppSt where
  constructor MkAppSt
  base_url       : String              -- NOT a secret (just a URL)
  active_project : Maybe Nat64Id      -- NOT a secret
  project_cache  : Maybe Project      -- NOT a secret

||| Token operations target GlobalAuthStore exclusively:
saveToken  : String -> Token -> IO ()    -- internally: save GlobalAuthStore ...
loadToken  : String -> IO (Maybe Token)  -- internally: load GlobalAuthStore ...
removeToken: String -> IO ()            -- internally: removeFile GlobalAuthStore ...

||| The Store type parameter on save/load/removeFile ensures that auth
||| operations can only target GlobalAuthStore, and workspace operations
||| can only target WorkspaceStore. There is no way to accidentally call
||| save WorkspaceStore on a Token value in the normal flow — the AuthStore
||| module encapsulates all Store choices for credentials.
```

