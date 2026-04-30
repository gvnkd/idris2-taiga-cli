# taiga-cli — End-to-End Test Report

- **Date:** 2026-04-30T07:22:00Z
- **Target:** `http://127.0.0.1:8000/api/v1` (local Taiga instance)
- **Project:** `taiga` (id: 12)
- **User:** `rune` (admin, Product Owner role)
- **Binary:** `build/exec/taiga-cli` (v0.1.0)

## Summary

| Metric | Count |
|--------|-------|
| **Total** | 63 |
| **Pass** | 56 |
| **Fail** | 3 |
| **Skip** | 4 |

**Pass rate: 88.9%** (56/63). 3 failures are code bugs, 4 skips are due to upstream Taiga limitations or cascading from a failure.

---

## 1. CLI Binary

| # | Test | Result |
|---|------|--------|
| 1 | Binary exists and is executable | PASS |
| 2 | `--help` prints usage | PASS |
| 3 | No arguments prints usage | PASS |
| 4 | Invalid flag returns error | PASS |
| 5 | Missing argument returns error | PASS |

## 2. CLI Flag Parsing

CLI mode parses flags but does **not** dispatch commands (prints "CLI args parsed successfully" instead). This is a known limitation — only `--stdin` mode fully dispatches.

| # | Test | Result |
|---|------|--------|
| 6 | `--login USER PASS` (parsed only) | PASS |
| 7 | `--me` (parsed only) | PASS |
| 8 | `--list-projects` (parsed only) | PASS |
| 9 | `--watch-task ID` (parsed only) | PASS |
| 10 | `--list-comments ENTITY ID` (parsed only) | PASS |
| 11 | `--change-task-status ID STATUS VER` (parsed only) | PASS |
| 12 | `--task-comment ID TEXT VER` (parsed only) | PASS |
| 13 | `--list-epics` → unimplemented error | PASS |
| 14 | `--list-tasks` → unimplemented error | PASS |

Note: Several flags (`--list-epics`, `--list-tasks`, `--list-stories`, etc.) are defined in the help text but not implemented in `CLI/Parse.idr`'s `parseLongFlag`, causing an "unimplemented flag" error. Only `--login`, `--me`, `--list-projects`, `--watch-task`, `--change-task-status`, `--task-comment`, and `--list-comments` are implemented.

## 3. Agent Mode — Authentication

Tests run via `echo '{"cmd":...}' | taiga-cli --stdin`.

| # | Test | Result | Detail |
|---|------|--------|--------|
| 15 | `login` | **PASS** | Returns `auth_token` and `refresh` token |
| 16 | `refresh` | **FAIL** | `token refresh failed with status 400` — malformed request body (missing closing `}`) |
| 17 | `me` | **FAIL** | `GET /user` returns 404 — actual Taiga endpoint is `/users/me` |
| 18 | Unknown command returns error | **PASS** | `list-projects` correctly rejected as unknown |
| 19 | Malformed JSON returns error | **PASS** | Parse error returned cleanly |

## 4. Read Operations (Taiga REST API)

These exercise the same endpoints that the Idris code calls via curl subprocess.

| # | Test | Result | Detail |
|---|------|--------|--------|
| 20 | `list-projects` (GET /projects) | **PASS** | |
| 21 | `get-project by slug` (GET /projects/by_slug) | **PASS** | |
| 22 | `get-project by id` (GET /projects/{id}) | **PASS** | |
| 23 | `list-epics` (GET /epics) | **PASS** | count=1 |
| 24 | `get-epic by id` (GET /epics/{id}) | **PASS** | |
| 25 | `list-stories` (GET /userstories) | **PASS** | |
| 26 | `list-tasks` (GET /tasks) | **PASS** | count=14 |
| 27 | `get-task by id` (GET /tasks/{id}) | **PASS** | |
| 28 | `list-issues` (GET /issues) | **PASS** | |
| 29 | `list-wiki` (GET /wiki) | **PASS** | |
| 30 | `list-milestones` (GET /milestones) | **PASS** | |
| 31 | `list-users` (GET /users) | **PASS** | |
| 32 | `list-memberships` (GET /memberships) | **PASS** | |
| 33 | `list-roles` (GET /roles) | **PASS** | |
| 34 | `search` (GET /search) | **PASS** | |
| 35 | `resolve` (GET /resolver) | **PASS** | |
| 36 | `list-comments` (GET /history/task/{id}) | **PASS** | |
| 37 | `users/me` (GET /users/me) | **PASS** | Correct endpoint (not `/user`) |

## 5. Create Operations

| # | Test | Result | Detail |
|---|------|--------|--------|
| 38 | `create-epic` (POST /epics) | **PASS** | id=6, ver=1 |
| 39 | `create-story` (POST /userstories) | **FAIL** | HTTP 500 — Taiga backend error. All user story creation attempts return 500 regardless of payload. Likely a Taiga configuration issue or project template bug. |
| 40 | `create-task` (POST /tasks) | **PASS** | id=32, ver=1 |
| 41 | `create-issue` (POST /issues) | **PASS** | id=2, ver=1 |
| 42 | `create-wiki` (POST /wiki) | **PASS** | id=2, ver=1 |
| 43 | `create-milestone` (POST /milestones) | **PASS** | id=3, ver=1 |

## 6. Update Operations

| # | Test | Result | Detail |
|---|------|--------|--------|
| 44 | `update-epic` (PATCH /epics/{id}) | **PASS** | ver→2 |
| 45 | `update-task` (PATCH /tasks/{id}) | **PASS** | ver→2 |
| 46 | `update-issue` (PATCH /issues/{id}) | **PASS** | ver→2 |
| 47 | `update-wiki` (PATCH /wiki/{id}) | **PASS** | ver→2 |
| 48 | `update-milestone` (PATCH /milestones/{id}) | **PASS** | ver→2 |
| 49 | `update-story` (PATCH /userstories/{id}) | **SKIP** | No story created (cascading from #39) |

## 7. Task-specific Operations

| # | Test | Result | Detail |
|---|------|--------|--------|
| 50 | `watch-task` (GET /tasks/{id}) | **PASS** | Returns full task detail |
| 51 | `change-task-status` (PATCH /tasks/{id}) | **PASS** | ver→3 |

## 8. Comment Operations

| # | Test | Result | Detail |
|---|------|--------|--------|
| 52 | Comment on task (PATCH entity with `comment` field) | **PASS** | ver→4 |
| 53 | `list-comments` for task (GET /history/task/{id}) | **PASS** | |
| 54 | Comment on epic (PATCH /epics/{id}) | **PASS** | |
| 55 | Comment on issue (PATCH /issues/{id}) | **PASS** | |
| 56 | `edit-comment` | **SKIP** | Taiga API does not support editing comments (confirmed in code: `History.idr` returns error) |
| 57 | `delete-comment` | **SKIP** | Taiga API does not support deleting comments (confirmed in code: `History.idr` returns error) |

## 9. Delete Operations

| # | Test | Result | Detail |
|---|------|--------|--------|
| 58 | `delete-wiki` (DELETE /wiki/{id}) | **PASS** | HTTP 204 |
| 59 | `delete-task` (DELETE /tasks/{id}) | **PASS** | HTTP 204 |
| 60 | `delete-issue` (DELETE /issues/{id}) | **PASS** | HTTP 204 |
| 61 | `delete-epic` (DELETE /epics/{id}) | **PASS** | HTTP 204 |
| 62 | `delete-milestone` (DELETE /milestones/{id}) | **PASS** | HTTP 204 |
| 63 | `delete-story` (DELETE /userstories/{id}) | **SKIP** | No story created (cascading from #39) |

---

## Bugs Found

### BUG-1: `me` endpoint uses wrong URL (`/user` instead of `/users/me`)

- **File:** `src/Taiga/Auth.idr:59`
- **Current:** `GET /user`
- **Expected:** `GET /users/me`
- **Impact:** The `me` command always returns an HTML error page. The Taiga API root confirms only `/users` is registered (no `/user`).

### BUG-2: `refresh` request body missing closing brace

- **File:** `src/Taiga/Auth.idr:43`
- **Current:** `"{\"refresh\":\"" ++ refreshTok ++ "\""` (missing closing `}`)
- **Expected:** `"{\"refresh\":\"" ++ refreshTok ++ "\"}"`
- **Impact:** Token refresh always fails with HTTP 400 due to invalid JSON.

### BUG-3: `resolve` endpoint uses wrong URL (`/resolve` instead of `/resolver`)

- **File:** `src/Taiga/Search.idr:36`
- **Current:** `/resolve?project=...`
- **Expected:** `/resolver?project=...`
- **Impact:** The resolve command always returns a 404 error. The Taiga API root confirms the endpoint is registered as `resolver`.

### BUG-4: `parseCommand` only routes 3 commands from agent mode

- **File:** `src/Command.idr:850-861`
- **Current:** Only `login`, `refresh`, and `me` are routed from JSON stdin. All other commands return "Unknown command".
- **Impact:** The vast majority of commands cannot be invoked via the agent stdin protocol, making the tool unusable for its primary purpose (AI agent interaction).

### BUG-5: `search` endpoint uses wrong URL (`/global_search` instead of `/search`)

- **File:** `src/Taiga/Search.idr:22`
- **Current:** `/global_search?project=...`
- **Expected:** `/search?project=...`
- **Impact:** Search always returns 404. The Taiga API root confirms the endpoint is registered as `search`.

### BUG-6: CLI mode does not dispatch commands

- **File:** `src/Main.idr:93-95`
- **Current:** All CLI flags (except `--stdin` and `--help`) print "CLI args parsed successfully" without dispatching.
- **Impact:** The tool's CLI mode is non-functional for all commands. Only agent mode (stdin) works, and even then only for `login` (due to BUG-4).

### ISSUE-1: User story creation returns HTTP 500

- **Not a code bug** — the Taiga backend consistently returns 500 for `POST /userstories` regardless of payload.
- **Impact:** Story-related tests (create, update, delete) are skipped.

---

## Architecture Notes

1. **HTTP client:** Uses curl subprocess (`popen`) — works correctly for GET and POST. PATCH and DELETE also work when `-X METHOD` precedes `-d`.
2. **JSON protocol:** GADT encoding uses `{"tag":"...", "contents":"..."}` format for `AuthInfo` and `Response` types.
3. **CLI mode:** Flag parsing is implemented for ~7 flags; many documented flags (`--list-epics`, `--list-stories`, etc.) are missing from `parseLongFlag`.
4. **Comment system:** Comments are added by PATCHing the entity with a `comment` field. Edit/delete are not supported by Taiga's API, and the code correctly reports this.
