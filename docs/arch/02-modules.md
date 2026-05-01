# Stateful Taiga CLI — Module Specification

## ⚠️ SECURITY ARCHITECTURE NOTE

**No credentials are stored in project directories.** The `AppSt` workspace state record contains NO auth fields. All secrets live exclusively under `~/.local/share/taiga-cli/tokens/`. Modules that handle auth (`AuthStore`, `State`) operate on the global directory for secrets and the local `./.taiga/` directory only for non-sensitive context data. This split is enforced by type design: the workspace `AppSt` has no auth fields, so it's structurally impossible to accidentally persist a token to `./.taiga/state.json`.

---

## New Modules

### `State/File.idr` — JSON Persistence Layer

**Responsibility**: Read/write typed values to named directories as JSON files. Supports both the workspace directory (`./.taiga/`) and the global auth directory (`~/.local/share/taiga-cli/tokens/`).

```idris
module State.File

import System.File
import JSON.ToJSON
import JSON.FromJSON

||| Storage location type. Enforces at compile time which directory an 
||| operation targets: WorkspaceStore is safe to commit, GlobalAuthStore
||| holds secrets that must never leave ~/.local/share/.
data Store = WorkspaceStore           -- ./.taiga/ (safe to commit)
           | GlobalAuthStore          -- ~/.local/share/taiga-cli/tokens/ (secrets)

||| Full path for a named file in the given store.
storePath : Store -> String -> String

||| Ensure the appropriate directory exists on disk.
ensureDir : Store -> IO ()

||| Load a value from a named file. Returns Nothing if missing or corrupt.
load  : FromJSON a => Store -> String -> IO (Maybe a)

||| Persist a value to a named file.
save  : ToJSON a => Store -> String -> a -> IO ()

||| Remove a file from the given store.
removeFile : Store -> String -> IO ()

||| Load and unwrap, or fail with a runtime error on missing/corrupt state.
||| Prefer using load directly for proper error handling; this is a 
||| convenience for internal bootstrap paths where failure is fatal.
loadOrCrash : FromJSON a => Store -> String -> String -> IO a
```

**Design notes**:
- The `Store` data type enforces at compile time which directory an operation targets
- Auth tokens can only be saved to/loaded from `GlobalAuthStore` — the type prevents writing secrets to workspace storage
- All I/O functions return `IO (Maybe _)` so callers must handle missing state explicitly; no silent crashes

---

### `State/State.idr` — Workspace State Model (No Secrets)

**Responsibility**: Define and manage the persistent workspace state. **Contains no credentials.**

```idris
module State.State

import Model.Common
import Model.Project
import State.File

||| Persistent workspace state stored in ./.taiga/state.json.
||| 
||| SECURITY: This record intentionally contains NO auth fields.
||| Credentials are managed separately by AuthStore and never
||| persisted here, ensuring they cannot leak via git commits.
record AppSt where
  constructor MkAppSt
  base_url       : String              -- Taiga API base URL (not a secret)
  active_project : Maybe Nat64Id      -- Active project ID (workspace context)
  project_cache  : Maybe Project      -- Cached full project metadata

%runElab derive "AppSt" [Show, ToJSON, FromJSON]

||| Default state for `init` command.
defaultState : String -> AppSt        -- takes base_url

||| Load workspace state. Returns Left with error message if not initialized.
loadState : IO (Either String AppSt)

||| Save workspace state to disk (no secrets). Returns Left on I/O error.
saveState : AppSt -> IO (Either String ())

||| Set the active project and persist. 
setActiveProject : Nat64Id -> IO (Either String ())

||| Invalidate project cache (e.g., after project-level mutation).
invalidateCache : IO (Either String ())

||| Get current base URL from state.
getBaseUrl : IO (Either String String)

||| Build an ApiEnv from workspace state + resolved auth.
||| Auth is fetched separately via AuthStore — see State/AuthStore.idr.
buildApiEnvWithToken : Model.Auth.Token -> AppSt -> ApiEnv
```

**Key invariant**: `AppSt` has no field of type `Token`, password-string, or any credential-bearing type. Combined with the fact that all I/O functions return `IO (Either String _)`, this makes it structurally impossible to accidentally persist secrets: there's nowhere in `AppSt` to put them, and every save/load goes through a typed channel that reports errors explicitly rather than crashing.

---

### `State/Config.idr` — Static Configuration

**Responsibility**: Store user preferences that don't change per session. Split between global config (`~/.local/share/taiga-cli/config.json`) and workspace config (`./.taiga/config.json`).

```idris
module State.Config

import JSON.ToJSON
import JSON.FromJSON
import State.File

||| Output format preference.
data OutputFormat = TextFmt | JsonFmt

%runElab derive "OutputFormat" [Show, Eq, ToJSON, FromJSON]

||| Global config stored in ~/.local/share/taiga-cli/config.json
record GlobalConfig where
  constructor MkGlobalConfig
  default_output_format : OutputFormat   -- Default output format
  default_base_url      : Maybe String    -- Default API base URL for init

%runElab derive "GlobalConfig" [Show, ToJSON, FromJSON]

||| Per-project config stored in ./.taiga/config.json
record WorkspaceConfig where
  constructor MkWorkspaceConfig
  output_format : Maybe OutputFormat  -- Overrides global default

%runElab derive "WorkspaceConfig" [Show, ToJSON, FromJSON]

||| Default configs.
defaultGlobalConfig    : GlobalConfig
defaultWorkspaceConfig : WorkspaceConfig

||| Load/save for global config.
loadGlobalConfig   : IO (Maybe GlobalConfig)
saveGlobalConfig   : GlobalConfig -> IO ()

||| Load/save for workspace config.
loadWorkspaceCfg   : IO (Maybe WorkspaceConfig)
saveWorkspaceCfg  : WorkspaceConfig -> IO ()

||| Resolve effective output format: workspace override > global default.
resolveOutputFormat : IO OutputFormat
```

---

### `State/AuthStore.idr` — Token Lifecycle Management (Global Storage)

**Responsibility**: Handle token persistence in the GLOBAL directory, expiration detection, and auto-refresh. Tokens are keyed by an instance hash derived from the base URL.

```idris
module State.AuthStore

import Model.Auth
import Taiga.Auth
import State.State
import State.File

||| Compute a stable identifier for a Taiga instance from its base URL.
||| Uses sha256 of the base URL string, truncated to a safe filename.
instanceHash : String -> String

||| Check if a token needs refresh (based on age or explicit flag).
needsRefresh : Token -> Bool

||| Load a token for a given instance. Returns Nothing if not authenticated.
loadToken : String            -- base_url
          -> IO (Maybe Token)

||| Save a token for a given instance.
saveToken : String           -- base_url
          -> Token 
          -> IO ()

||| Remove a token for a given instance (logout).
removeToken : String         -- base_url
            -> IO ()

||| Attempt to refresh a token using the stored refresh token.
||| Returns new token on success, original on failure.
tryRefresh : String           -- base URL
           -> Token          -- current (possibly stale) token
           -> IO (Either String Token)

||| Authenticate with credentials and persist the token globally.
authenticate : String         -- base URL
             -> Credentials  -- username + password
             -> IO (Either String Token)

||| Resolve auth for a workspace: load state, look up token, 
||| refresh if needed. Returns the ApiEnv ready for API calls.
resolveAuth : AppSt -> IO (Either String ApiEnv)
```

**Security**: All file operations target `GlobalAuthStore`. The `instanceHash` function ensures tokens for different Taiga instances don't collide, and the hash is a one-way mapping — you can't derive the base URL from the filename alone.

---

### `CLI/Output.idr` — Dual-Format Output

**Responsibility**: Format any result as human-readable text or JSON.

```idris
module CLI.Output

import State.Config
import JSON.ToJSON

||| Render a value in the selected format.
render : (ToJSON a, Show a) => OutputFormat -> a -> String
  where
    render TextFmt _ = show           -- human-readable via Show instance
    render JsonFmt _ = encode        -- JSON via ToJSON instance

||| Pretty-print a list of tasks as a text table.
renderTaskTable : List TaskSummary -> String

||| Pretty-print a list of projects as a text table.
renderProjectTable : List ProjectSummary -> String

||| Render a command result (either error or success).
renderResult : ToJSON a => OutputFormat -> Either String a -> String
```

---

### `CLI/Subcommand.idr` — Subcommand Routing

**Responsibility**: Parse subcommand structure and dispatch to action handlers.

```idris
module CLI.Subcommand

||| Description of what the user wants to do.
data Action : Type where
  -- Core
  ActInit                  : Maybe String -> Action -- base_url (Nothing→default)
  ActLogin                 : Credentials -> Action
  ActLogout                : Action
  ActShow                  : Action
  
  -- Project
  ActProjectList           : Action
  ActProjectSet            : String -> Action       -- slug or id string
  ActProjectGet            : Action
  
  -- Task (operates on active project)
  ActTaskList              : Maybe String -> Action -- optional status filter
  ActTaskCreate            : String -> Action        -- subject
  ActTaskGet               : Nat64Id -> Action
  ActTaskStatus            : (Nat64Id, Bits64) -> Action  -- task_id + target status id
  ActTaskComment           : (Nat64Id, String) -> Action -- task_id + comment text
  
  -- Epic
  ActEpicList              : Action
  ActEpicGet               : Nat64Id -> Action
  
  -- Sprint/Milestone
  ActSprintShow            : Action
  ActSprintList            : Action
  ActSprintSet             : Nat64Id -> Action
  
  -- Issue (analogous to task)
  ActIssueList             : Action
  ActIssueCreate           : String -> Action
  ActIssueGet              : Nat64Id -> Action
  
  -- Story (analogous to task)
  ActStoryList             : Action
  ActStoryGet              : Nat64Id -> Action

%runElab derive "Action" [Show]

||| Parse CLI args into an Action.
parseAction : List String -> Either String Action

||| Execute an action, returning a formatted string for stdout.
executeAction : Action -> IO (Either String ())
```

**Note**: `Bits64` is used for the status field in `ActTaskStatus` because task statuses are opaque integers from the Taiga API with no guaranteed structure. The tuple form `(Nat64Id, Bits64)` follows Idris2 conventions for multi-argument constructors of the same type to avoid ambiguity.

---

## Modified Existing Modules

### `Main.idr` — Entry Point

Changes: 
- Empty args → print help (unchanged)
- `["--stdin"]` → agent mode (unchanged)  
- Everything else → route through `CLI.Subcommand.parseAction` + `executeAction`

```idris
main : IO ()
main = do
  args <- drop 1 <$> getArgs
  case args of
    []          => putStrLn usageText           -- help
    ["--stdin"] => runAgent                      -- legacy agent mode
    _           => do
      result <- executeAction (parseAction' args)
      outputResult result

  where
    parseAction' : List String -> Action
    parseAction' args = 
       case parseAction args of
         Left err => crash $ "error: " ++ err
         Right action => action
    
    crash : String -> a
    crash msg = do
      hPutStrLn stderr msg
      exitWith (ExitFailure 1)

||| Format and print either success or error to stdout/stderr.
outputResult : Either String () -> IO ()
outputResult (Left err)  = do
  hPutStrLn stderr ("error: " ++ err)
  exitWith (ExitFailure 1)
outputResult (Right _)   = pure ()
```

### `CLI/Parse.idr` — Extended Parser

The existing hand-rolled parser is extended to handle the subcommand structure. The verb (`task`, `project`, etc.) is the first arg, the action (`list`, `create`, `set`) is the second, and remaining args are parsed per-action. Note: all parse failures produce `Left String`, never crash — Main.idr is the only layer that calls `exitWith`.

### `CLI/Help.idr` — Updated Help Text

The usage text is updated to document the new subcommand interface. The old flag-based help remains for backward compatibility (agent mode still uses flags internally).

---

## Unchanged Modules

These modules require no modifications:

| Module | Reason |
|--------|--------|
| `Taiga/*.idr` | API layer stays stateless, auto-implicit ApiEnv pattern |
| `Model/*.idr` | Data model records are unchanged; new types added alongside if needed |
| `Protocol/*.idr` | Request/Response envelopes used by agent mode, untouched |
| `Command.idr` | Agent-mode dispatch table remains for backward compat |
