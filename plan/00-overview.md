# taiga-cli — High-Level Implementation Plan

## 1. Purpose

`taiga-cli` is a command-line tool written in Idris2 that lets AI agents interact with a
Taiga project-management instance over its REST API (`/api/v1`). It exposes a compact
JSON-over-stdin/stdout protocol so an agent can authenticate, query, create and edit
Taiga entities with minimal token overhead.

---

## 2. Architecture

```
┌─────────────────────────────────────────────────┐
│                  CLI entry point                 │
│              (src/Main.idr)                      │
│                                                 │
│  Reads one JSON request from stdin              │
│  ──▶ dispatches to Command handler              │
│  ──▶ writes one JSON response to stdout         │
└─────────────┬───────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────┐
│              Command layer                       │
│          (src/Command.idr)                       │
│                                                 │
│  Sum type `Command` — one constructor per       │
│  agent-visible operation.                       │
│  Each command maps to one HTTP call (or a       │
│  short sequence).                               │
└─────────────┬───────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────┐
│              Taiga API client                    │
│          (src/Taiga.idr)                        │
│                                                 │
│  HTTP helper (via idris2-cptr / libc)           │
│  Auth token management                          │
│  Typed request builders per endpoint            │
│  JSON response parsers                          │
└─────────────┬───────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────┐
│           Data model  (src/Model/)               │
│                                                 │
│  Auth       — Token, credentials                │
│  Project    — slug, id, name, description       │
│  Epic       — id, ref, subject, status, …      │
│  UserStory  — id, ref, subject, milestone, …   │
│  Task       — id, ref, subject, status, …      │
│  Issue      — id, ref, subject, priority, …    │
│  WikiPage   — id, slug, content, …             │
│  Milestone  — id, name, dates, …               │
│  User       — id, username, full_name, …       │
│  Comment    — id, text, …                      │
│  History    — comment diff entries              │
│                                                 │
│  Each record: FromJSON / ToJSON instances       │
│  Compact serialisation aliases                  │
└─────────────────────────────────────────────────┘
```

---

## 3. JSON Protocol Design

Every invocation reads **one JSON object** from stdin and writes **one JSON object**
to stdout. This keeps the protocol simple, parseable, and token-efficient.

### 3.1 Request envelope

```json
{
  "cmd":   "<command>",
  "args":  { … },
  "auth":  { "token": "…" },
  "base":  "https://taiga.example.com"
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `cmd` | yes      | Command name, e.g. `"login"`, `"list-projects"` |
| `args`| per-cmd  | Command-specific parameters |
| `auth`| most cmds| `{"token":"…"}` or `{"user":"…","pass":"…"}` |
| `base`| no       | Taiga API base URL (default from config / env `TAIGA_URL`) |

### 3.2 Response envelope

**Success:**

```json
{"ok": true,  "data": { … }}
```

**Error:**

```json
{"ok": false, "err": "not-found", "msg": "Project 42 not found"}
```

### 3.3 Compact output mode

Responses use short field names to minimise tokens. Example list response:

```json
{
  "ok": true,
  "data": [
    {"id":1,"slug":"my-proj","name":"My Project"},
    {"id":2,"slug":"other",  "name":"Other"}
  ]
}
```

Full-detail GET responses include all useful fields but still prefer short keys
where unambiguous. A `verbose` flag in args can request the full Taiga payload
verbatim when an agent needs every field.

---

## 4. Command Catalogue

### 4.1 Authentication

| cmd | args | description |
|-----|------|-------------|
| `login` | `{"user":"…","pass":"…"}` | Exchange credentials for auth token. Returns `{"token":"…","refresh":"…"}` |
| `refresh` | `{"refresh":"…"}` | Refresh an expiring token |
| `me` | — | Get current authenticated user profile |

`auth` block also accepts `{"user":"…","pass":"…"}` on any command to auto-login,
but the agent should prefer storing the token from `login` and reusing it.

### 4.2 Read-only / List commands

| cmd | key args | description |
|-----|----------|-------------|
| `list-projects` | `?member` | List visible projects |
| `get-project` | `id` or `slug` | Project detail |
| `list-epics` | `project` | List epics in a project |
| `get-epic` | `id` or `ref`+`project` | Epic detail |
| `list-stories` | `project` | List user stories |
| `get-story` | `id` or `ref`+`project` | User story detail |
| `list-tasks` | `project` or `story` | List tasks |
| `get-task` | `id` or `ref`+`project` | Task detail |
| `list-issues` | `project` | List issues |
| `get-issue` | `id` or `ref`+`project` | Issue detail |
| `list-wiki` | `project` | List wiki pages |
| `get-wiki` | `id` or `slug`+`project` | Wiki page with content |
| `list-milestones` | `project` | List milestones/sprints |
| `list-users` | `project` | List project members |
| `list-memberships` | `project` | List memberships |
| `list-roles` | `project` | List roles |
| `search` | `project`, `text` | Global project search |
| `resolve` | `project`, `epic`/`story`/`task`/`wiki` (slug or ref) | Resolve entity by slug/ref |

All list commands support pagination args `page` and `pageSize`, and return
compact arrays by default. Header-based pagination info is folded into the
response: `{"ok":true,"data":[…],"count":47,"page":1,"pages":5}`.

### 4.3 Write / mutation commands

| cmd | key args | description |
|-----|----------|-------------|
| `create-epic` | `project`, `subject`, `?description`, `?status` | Create epic |
| `update-epic` | `id`, `?subject`, `?description`, `?status`, `version` | Update epic |
| `delete-epic` | `id` | Delete epic |
| `create-story` | `project`, `subject`, `?description`, `?milestone` | Create user story |
| `update-story` | `id`, fields…, `version` | Update user story |
| `delete-story` | `id` | Delete user story |
| `create-task` | `project`, `subject`, `?story`, `?description`, `?status` | Create task |
| `update-task` | `id`, fields…, `version` | Update task |
| `delete-task` | `id` | Delete task |
| `create-issue` | `project`, `subject`, `?description`, `?priority`, `?severity`, `?type` | Create issue |
| `update-issue` | `id`, fields…, `version` | Update issue |
| `delete-issue` | `id` | Delete issue |
| `create-wiki` | `project`, `slug`, `content` | Create wiki page |
| `update-wiki` | `id`, `?content`, `?slug`, `version` | Update wiki page |
| `delete-wiki` | `id` | Delete wiki page |
| `comment` | `entity` (`"task"`/`"story"`/`"epic"`/`"issue"`), `id`, `text` | Add comment (via history API) |
| `edit-comment` | `entity`, `id`, `comment_id`, `text` | Edit existing comment |
| `delete-comment` | `entity`, `id`, `comment_id` | Delete comment |
| `create-milestone` | `project`, `name`, `estimated_start`, `estimated_finish` | Create milestone |
| `update-milestone` | `id`, fields…, `version` | Update milestone |

All mutation commands honour Taiga's OCC: the `version` field must match the
current entity version. The tool returns the updated entity on success so the
agent always has the latest `version`.

---

## 5. Module Layout (src/)

```
src/
├── Main.idr              — CLI entry: read JSON, dispatch, write JSON
├── Command.idr           — Command sum type + dispatch table
├── Taiga/
│   ├── Api.idr           — HTTP client wrapper (GET/POST/PUT/PATCH/DELETE)
│   ├── Auth.idr          — Login, refresh, token storage
│   ├── Project.idr       — Project endpoints
│   ├── Epic.idr          — Epic endpoints + related user stories
│   ├── UserStory.idr     — User story endpoints
│   ├── Task.idr          — Task endpoints
│   ├── Issue.idr         — Issue endpoints
│   ├── Wiki.idr          — Wiki page endpoints
│   ├── Milestone.idr     — Milestone endpoints
│   ├── User.idr          — User/member endpoints
│   ├── History.idr       — Comments (history) endpoints
│   └── Search.idr        — Resolver + search endpoints
├── Model/
│   ├── Auth.idr          — Token, credentials types + JSON instances
│   ├── Project.idr       — Project record + JSON
│   ├── Epic.idr          — Epic record + JSON
│   ├── UserStory.idr     — UserStory record + JSON
│   ├── Task.idr          — Task record + JSON
│   ├── Issue.idr         — Issue record + JSON
│   ├── WikiPage.idr      — WikiPage record + JSON
│   ├── Milestone.idr     — Milestone record + JSON
│   ├── User.idr          — User record + JSON
│   ├── Comment.idr       — Comment / history entry + JSON
│   └── Common.idr        — Shared types: Nat64Id, Slug, Version, etc.
└── Protocol/
    ├── Request.idr        — Request envelope parser
    └── Response.idr       — Response envelope serialiser (compact)
```

---

## 6. Key Idris2 Libraries (from flake)

| Library | Usage |
|---------|-------|
| `idris2-json` | JSON parsing (FromJSON) and serialisation (ToJSON) |
| `idris2-bytestring` | HTTP body handling |
| `idris2-parser` | Command-line argument parsing if needed |
| `idris2-containers` | SortedMap / HashMap for config lookups |
| `idris2-cptr` | C FFI bindings — HTTP requests via libcurl or raw sockets |
| `idris2-async` | Optional: async HTTP for future parallel requests |
| `idris2-filepath` | Config file path resolution |
| `idris2-elab-util` | Deriving JSON instances via elaboration |
| `idris2-refined` | Refined types for validated IDs, slugs |

### HTTP client strategy

The most pragmatic approach is to shell out to `curl` (via `System.run`) or use
a minimal C FFI wrapper around libcurl via `idris2-cptr`. This avoids
reimplementing TLS and HTTP/1.1 in pure Idris. The initial implementation will
use `curl` subprocess calls for maximum reliability; a later phase can migrate
to a native HTTP client.

---

## 7. Implementation Phases

### Phase 1 — Foundation (src/Taiga/Api.idr, src/Model/, src/Protocol/)

- HTTP client wrapper (curl subprocess)
- JSON request/response envelope
- Data model types + JSON instances for all entities
- Basic error handling

### Phase 2 — Authentication (src/Taiga/Auth.idr, src/Command.idr)

- `login` command (username/password → token)
- `refresh` command
- `me` command
- Token passed in `Authorization: Bearer …` header

### Phase 3 — Read operations (list-* and get-*)

- All list commands with pagination support
- All get-by-id and get-by-ref commands
- Resolver and search endpoints
- Compact JSON output

### Phase 4 — Write operations (create-*, update-*, delete-*)

- CRUD for epics, user stories, tasks, issues, wiki pages, milestones
- OCC version handling
- Comment create / edit / delete via history API

### Phase 5 — Polish

- Config file support (`~/.config/taiga-cli/config.json` or env vars)
- Error taxonomy (auth-expired, not-found, forbidden, rate-limit, network)
- Integration tests against a live Taiga instance
- Optional: native HTTP client replacing curl
- Optional: batch/multi-command mode

---

## 8. Example Sessions

### Login

```json
// stdin
{"cmd":"login","args":{"user":"admin","pass":"1234"},"base":"https://taiga.example.com"}
// stdout
{"ok":true,"data":{"token":"eyJ...","refresh":"abc...","user":{"id":1,"name":"Admin"}}}
```

### List projects

```json
// stdin
{"cmd":"list-projects","auth":{"token":"eyJ..."}}
// stdout
{"ok":true,"data":[{"id":1,"slug":"backend","name":"Backend"},{"id":2,"slug":"frontend","name":"Frontend"}]}
```

### Create task

```json
// stdin
{"cmd":"create-task","args":{"project":"backend","subject":"Fix auth bug","story":42},"auth":{"token":"eyJ..."}}
// stdout
{"ok":true,"data":{"id":107,"ref":107,"subject":"Fix auth bug","status":"New","version":1}}
```

### Add comment

```json
// stdin
{"cmd":"comment","args":{"entity":"task","id":107,"text":"Root cause identified: missing null check in token validation."},"auth":{"token":"eyJ..."}}
// stdout
{"ok":true,"data":{"id":503,"text":"Root cause identified: missing null check in token validation."}}
```

---

## 9. Design Principles

1. **Token-minimal protocol** — short field names, omit nulls, arrays over objects
2. **One-shot JSON I/O** — single request per invocation, no interactive mode needed
   for agents (but could be added later for humans)
3. **Idempotent reads** — GET operations are safe to repeat
4. **OCC-aware writes** — every mutation requires `version`; tool returns updated entity
5. **Fail loudly** — structured errors with `err` code + human `msg`
6. **Deterministic output** — same input always produces same output shape
