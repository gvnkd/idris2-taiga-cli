# Stateful Taiga CLI — Data Flow

## Request Lifecycle

```
User input (CLI args)
       │
       ▼
┌──────────────┐
│  Main.main   │  ← Entry point: routes to agent mode or subcommand mode
│  (Main.idr)  │
└──────┬───────┘
       │  (subcommand path)
       ▼
┌──────────────┐
│  Subcommand   │  ← Parses verb+noun into an action description
│  Router       │     e.g. "task list" → ActionListTasks
│               │     e.g. "project set taiga" → ActionSetProject "taiga"
└──────┬───────┘
       │
       ▼
┌──────────────┐     ┌────────────────────┐
│  State Load  │◀────│ ./.taiga/state.json │  ← Workspace state (no secrets)
│              │     │   (AppSt)            │     active_project, base_url_ref
└──────┬───────┘     └───────────────────┘
       │
       │  (AppSt.base_url → compute instance_hash = sha256(base_url))
       ▼
┌──────────────────┐   ┌──────────────────────────────┐
│  Auth Resolve    │◀─▶│ ~/.local/share/taiga-cli/     │  ← ⚠️ SECRETS HERE
│                  │   │   tokens/<instance_hash>.json │     (git-ignore safe)
│  (AuthStore.idr) │   └──────────────────────────────┘
└────────┬─────────┘            │
         │                     │  Token lookup by instance_hash
         │          ┌──────────▼─────────┐
         │          │ Auth token resolved │
         │          │ + refresh on 401    │
         ▼          └────────────────────┘
┌──────────────┐
│  ApiEnv      │  ← Constructed from base_url + resolved auth token:
│  Construction│     MkApiEnv base_url resolved_token.auth_token
└──────┬───────┘
       │
       ▼
┌──────────────┐
│  Taiga/*     │  ← Existing API modules (unchanged)
│  API Layer   │     Functions receive ApiEnv via auto-implicit
└──────┬───────┘
       │
       ▼
┌──────────────┐
│  State Save  │  ← If action mutated workspace state, persist
│              │     updated AppSt back to ./taiga/state.json (no secrets)
│              │     If auth changed, persist token separately to global dir
└──────┬───────┘
       │
       ▼
┌──────────────┐
│  Output      │  ← Format result: human-readable text OR JSON (--json flag)
│  Formatter   │
└──────────────┘
```

## ⚠️ SECURITY BOUNDARY

The horizontal line between workspace state (`./.taiga/state.json`) and auth storage (`~/.local/share/taiga-cli/tokens/`) is a **hard security boundary**. The two storage locations never exchange credentials directly:

- Workspace state knows only an opaque `base_url` string
- Auth store is keyed by `sha256(base_url)` — the workspace never sees the hash or the token
- Even if `./taiga/state.json` is committed to a public Git repo, no credentials are exposed

## Detailed Flow: `taiga-cli task list`

Step by step for the command `taiga-cli task list`:

1. **Main** receives args `["task", "list"]`
2. **Subcommand router** parses `"task"` → Task domain, `"list"` → ActionListTasks
3. **Workspace state load** reads `./.taiga/state.json` into `AppSt` (no secrets)
4. **Auth resolve**: compute `instance_hash = sha256(AppSt.base_url)`, load token from `~/.local/share/taiga-cli/tokens/<hash>.json`
5. **Validation**: check that `active_project` is `Just id` AND auth token is present (error if either missing)
6. **Token freshness**: verify token hasn't expired; attempt refresh if stale or on 401
7. **Build ApiEnv** from resolved `base_url` and `auth_token`
8. **Dispatch**: call `listTasks @{env} project Nothing Nothing Nothing`
9. **Result**: get `Either String (List TaskSummary)` from Taiga API
10. **No state mutation**: skip save (read-only operation)
11. **Format**: render `List TaskSummary` as a text table (or JSON array if `--json`)

## Detailed Flow: `taiga-cli project set taiga`

1. **Main** receives args `["project", "set", "taiga"]`
2. **Router** parses → ActionSetProject "taiga"
3. **Workspace state load** reads current `AppSt` from `./taiga/state.json`
4. **Auth resolve** (as above): look up token by instance hash from global storage
5. **Validation**: check auth token is present
6. **Build ApiEnv** from existing state's base_url and resolved token
7. **API call**: `getProjectBySlug @{env} (MkSlug "taiga")` to resolve slug → Nat64Id
8. **Workspace state mutation**: update `active_project` field in AppSt to the resolved ID
9. **Save workspace state** to `./.taiga/state.json` (no secrets written)
10. **Format**: print confirmation text, e.g., "Active project: Taiga (id=12)"

## Detailed Flow: `taiga-cli login --user U --pass P`

This is the only command that writes to the global auth directory:

1. **Auth**: `POST /auth` with credentials → receives `Token { auth_token, refresh }`
2. **Compute instance_hash**: `sha256(base_url)` from workspace state (or resolved base URL)
3. **Persist token**: write Token to `~/.local/share/taiga-cli/tokens/<instance_hash>.json`
4. **Format**: print "Authenticated successfully"

## Token Lifecycle

```
User runs `taiga-cli login --user U --pass P`
           │
           ▼
   POST /auth with credentials → receives Token { auth_token, refresh }
           │
           ▼
   Compute instance_hash = sha256(base_url)
           │
           ▼
  Persist Token to ~/.local/share/taiga-cli/tokens/<instance_hash>.json
              ⚠️ NEVER written to ./.taiga/ ─────────────────────⚠️ SECURITY

──────────────────── subsequent invocations ────────────────────

Every command:
  1. Load workspace AppSt from disk (./.taiga/state.json) — no secrets
  2. Compute instance_hash = sha256(AppSt.base_url)
  3. Look up token at ~/.local/share/taiga-cli/tokens/<hash>.json
  4. If token missing → error "not authenticated. Run 'taiga-cli login'"
  5. API call with token → if HTTP 401 received:
     a. Use Token.refresh to call POST /auth/refresh
     b. Store refreshed Token in global dir (same path, overwrite)
     c. Retry original request

User runs `taiga-cli logout`
           │
           ▼
   Delete ~/.local/share/taiga-cli/tokens/<instance_hash>.json
   (Workspace state ./taiga/state.json is unaffected — still has project context)
```

## State Isolation Guarantees

- Each working directory maintains its own `./.taiga/` workspace state (project context, no secrets)
- Auth tokens are global per-user, keyed by Taiga instance URL hash
- Running `taiga-cli init` in `/home/pion/project-a/` creates independent workspace from `/home/pion/project-b/`
- Both workspaces can point to the same Taiga instance and share the same auth token transparently
- A user can maintain separate contexts for different Taiga instances by initializing with different base URLs

## Caching Strategy

The `project_cache : Maybe Project` field in `AppSt` caches full project metadata. It is:
- Populated on first access after `project set`
- Considered stale when the OCC `version` field changes on re-fetch
- Invalidation triggered by any write operation that affects project-level data

For now, caching is best-effort and local to the workspace state file. There's no in-memory cache — every invocation reads from disk. Future optimization could add a TTL or version-check based invalidation.

