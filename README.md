# taiga-cli

A command-line tool written in [Idris 2](https://github.com/idris-lang/Idris2) that lets AI agents and human users interact with a [Taiga](https://taiga.io) project management instance over its REST API.

## Features

- **Agent mode** (default): reads one JSON request from stdin, dispatches the command, writes one JSON response to stdout
- **Subcommand mode** (new): stateful verb-noun commands (`taiga-cli task list`, `taiga-cli project set taiga`)
- **Legacy CLI mode**: human-friendly flags (`--list-epics`, `--login`, etc.) with plain JSON output
- Full CRUD for epics, user stories, tasks, issues, wiki pages, and milestones via subcommand CLI
- Ref-first identifiers — all entity lookups accept user-facing ref IDs (not just internal DB IDs)
- Comment management via the Taiga history API
- Global project search and entity resolution by slug/ref
- Token-minimal compact JSON protocol
- OCC (optimistic concurrency control) version handling on all mutations
- Structured error responses with error codes and messages
- Stateful workspace with secure auth storage

## Building

### Prerequisites

- [Nix](https://nixos.org/) with [flakes enabled](https://nixos.wiki/wiki/Flakes)
- Alternatively: Idris 2 with the `json` package available

### With Nix (recommended)

```shell
nix develop
build
```

This drops you into a development shell with Idris 2 and all dependencies, then builds the project.

### Without Nix

```shell
idris2 --build taiga-cli.ipkg
```

The compiled binary is placed at `build/exec/taiga-cli`.

## Running

```shell
# Show help
./build/exec/taiga-cli --help

# Run via nix
nix develop --command run
```

## Usage

### Subcommand Mode (Stateful)

The subcommand mode maintains workspace state in `./.taiga/` and authenticates via `~/.local/share/taiga-cli/`.

All entity commands operate on the **active project** set via `project set`.
All entity lookups accept **ref IDs** (user-facing numbers from the Taiga UI) or raw database IDs.

```shell
# Initialize workspace state
taiga-cli init http://127.0.0.1:8000/api/v1

# Authenticate interactively (password read from prompt, token stored in global auth dir)
taiga-cli login --user admin

# Authenticate with piped password
echo "secretpassword" | taiga-cli login --user admin

# Authenticate with command-line password (WARNING: insecure, visible in shell history)
taiga-cli login --user admin --password secretpassword

# Switch project context
taiga-cli project set my-project

# Show current state
taiga-cli show

# Output JSON instead of text
taiga-cli task list --json
```

### Legacy CLI Mode

```shell
# Authenticate
taiga-cli --login admin secretpassword --base http://127.0.0.1:8000/api/v1

# List projects
taiga-cli --list-projects --token "eyJ..." --base http://127.0.0.1:8000/api/v1

# List epics in a project
taiga-cli --list-epics my-project --token "eyJ..." --base http://127.0.0.1:8000/api/v1

# Get a task by ID
taiga-cli --get-task 42 --token "eyJ..." --base http://127.0.0.1:8000/api/v1

# Search within a project
taiga-cli --search my-project "auth bug" --token "eyJ..." --base http://127.0.0.1:8000/api/v1
```

### Agent Mode (stdin/stdout JSON)

Pipe a JSON request to stdin and read a JSON response from stdout:

```shell
# Login
echo '{"cmd":"login","args":"{\"username\":\"admin\",\"password\":\"1234\"}","base":"http://127.0.0.1:8000/api/v1"}' \
  | taiga-cli --stdin

# List projects
echo '{"cmd":"list-projects","args":"{\"member\":null,\"listProjectsTag\":\"\"}","auth":{"tag":"TokenAuth","contents":"eyJ..."},"base":"http://127.0.0.1:8000/api/v1"}' \
  | taiga-cli --stdin

# Create a task
echo '{"cmd":"create-task","args":"{\"project\":\"backend\",\"subject\":\"Fix auth bug\",\"story\":null,\"description\":null,\"status\":null,\"milestone\":null}","auth":{"tag":"TokenAuth","contents":"eyJ..."},"base":"http://127.0.0.1:8000/api/v1"}' \
  | taiga-cli --stdin
```

## Security: State Storage

**Credentials are NEVER stored in the project directory.**

| Data Type | Storage Location | Safe to commit |
|-----------|-------------------|----------------|
| **Auth tokens, refresh tokens** | `~/.local/share/taiga-cli/tokens/` | No |
| **Workspace state** (active project, base URL) | `./.taiga/state.json` | Yes |
| **Config** (output format prefs) | `./.taiga/config.json` | Yes |

The workspace state (`AppSt`) has no auth fields — it's structurally impossible to persist a token to `./.taiga/`. Auth is resolved at runtime by looking up the instance hash of the base URL in the global tokens directory.

## JSON Protocol

### Request

```json
{
  "cmd":   "<command>",
  "args":  "{}",
  "auth":  { "tag": "TokenAuth", "contents": "..." },
  "base":  "http://127.0.0.1:8000/api/v1"
}
```

| Field  | Required  | Description                                                |
|--------|-----------|------------------------------------------------------------|
| `cmd`  | yes       | Command name, e.g. `"login"`, `"list-projects"`           |
| `args` | per-cmd   | Command-specific parameters (JSON string)                  |
| `auth` | most cmds | `{"tag":"TokenAuth","contents":"..."}` or credential auth  |
| `base` | no        | Taiga API base URL                                         |

### Response

Success:

```json
{"tag":"Ok","contents":{"ok":true,"payload":"{...}"}}
```

Error:

```json
{"tag":"Err","contents":{"ok":false,"err":"not-found","msg":"Project 42 not found"}}
```

## Command Reference

### Subcommand Mode

```
taiga-cli <verb> [<action>] [args...] [--json]

Core:
  init [URL]                    Create state directory and default config
  login --user U [--password P] Authenticate, persist token globally
  logout                        Clear persisted token
  show                          Display current state

Project context:
  project list                  List accessible projects
  project set <slug|id>         Switch active project
  project get                   Show active project details

Entity operations (on active project, id = ref-id or db-id):

  task list [--status S]                List tasks
  task create <subject>                 Create task
  task get <id>                         Get task
  task update <id> [--subject S] [--description D] [--status ST]
                                        Update task
  task delete <id>                      Delete task (prompts for confirmation)
  task status <id> <status-id>          Change task status
  task comment <id> <text>              Comment on a task

  epic list                             List epics
  epic get <id>                         Get epic
  epic create <subject> [--description D] [--status ST]
                                        Create epic
  epic update <id> [--subject S] [--description D] [--status ST]
                                        Update epic
  epic delete <id>                      Delete epic

  story list                            List stories
  story get <id>                        Get story
  story create <subject> [--description D] [--milestone M]
                                        Create story
  story update <id> [--subject S] [--description D] [--milestone M]
                                        Update story
  story delete <id>                     Delete story

  issue list                            List issues
  issue get <id>                        Get issue
  issue create <subject> [--description D] [--priority P] [--severity S] [--type T]
                                        Create issue
  issue update <id> [--subject S] [--description D] [--type T]
                                        Update issue
  issue delete <id>                     Delete issue

  sprint list                           List sprints/milestones
  sprint show                           Show current sprint state
  sprint set <id>                       Set active sprint
  sprint create <name> [--start DATE] [--end DATE]
                                        Create sprint
  sprint update <id> --version VER [--name N] [--start DATE] [--end DATE]
                                        Update sprint (needs --version)
  sprint delete <id>                    Delete sprint

  wiki list                             List wiki pages
  wiki get <id>                         Get wiki page
  wiki create <slug> <content>          Create wiki page
  wiki update <id> [--content C] [--slug S]
                                        Update wiki page
  wiki delete <id>                      Delete wiki page

Comments:
  comment add <entity> <id> <text>      Add comment to entity
  comment list <entity> <id>            List comments on entity
                                        entity: task, issue, story, wiki

Resolution:
  resolve <ref>                         Resolve ref to entity details
```

### Agent Mode Commands

#### Authentication

| cmd       | args                          | description                       |
|-----------|-------------------------------|-----------------------------------|
| `login`   | `{"username":"...","password":"..."}` | Exchange credentials for token |
| `refresh` | `{"refresh":"..."}`           | Refresh an expiring token         |
| `me`      | —                             | Get current user profile          |

#### Read Operations

| cmd                  | key args                   | description                    |
|----------------------|----------------------------|--------------------------------|
| `list-projects`      | `?member`                  | List visible projects          |
| `get-project`        | `id` or `slug`             | Project detail                 |
| `list-epics`         | `project`                  | List epics                     |
| `get-epic`           | `id`                       | Epic detail                    |
| `list-stories`       | `project`                  | List user stories              |
| `get-story`          | `id`                       | User story detail              |
| `list-tasks`         | `?project`                 | List tasks                     |
| `get-task`           | `id`                       | Task detail                    |
| `list-issues`        | `project`                  | List issues                    |
| `get-issue`          | `id`                       | Issue detail                   |
| `list-wiki`          | `project`                  | List wiki pages                |
| `get-wiki`           | `id`                       | Wiki page with content         |
| `list-milestones`    | `project`                  | List milestones/sprints        |
| `list-users`         | `project`                  | List project members           |
| `list-memberships`   | `project`                  | List memberships               |
| `list-roles`         | `project`                  | List roles                     |
| `search`             | `project`, `text`          | Global project search          |
| `resolve`            | `project`, `ref`           | Resolve entity by slug/ref     |
| `list-comments`      | `entity`, `id`             | List comments/history          |

#### Write Operations

| cmd                  | key args                                            | description             |
|----------------------|-----------------------------------------------------|-------------------------|
| `create-epic`        | `project`, `subject`, `?description`, `?status`     | Create epic             |
| `update-epic`        | `id`, fields..., `version`                          | Update epic             |
| `delete-epic`        | `id`                                                | Delete epic             |
| `create-story`       | `project`, `subject`, `?description`, `?milestone`  | Create user story       |
| `update-story`       | `id`, fields..., `version`                          | Update user story       |
| `delete-story`       | `id`                                                | Delete user story       |
| `create-task`        | `project`, `subject`, `?story`, `?description`      | Create task             |
| `update-task`        | `id`, fields..., `version`                          | Update task             |
| `delete-task`        | `id`                                                | Delete task             |
| `watch-task`         | `id`                                                | Get task details        |
| `change-task-status` | `id`, `status`, `version`                           | Change task status      |
| `task-comment`       | `id`, `text`, `version`                             | Comment on a task       |
| `create-issue`       | `project`, `subject`, `?priority`, `?severity`      | Create issue            |
| `update-issue`       | `id`, fields..., `version`                          | Update issue            |
| `delete-issue`       | `id`                                                | Delete issue            |
| `create-wiki`        | `project`, `slug`, `content`                        | Create wiki page        |
| `update-wiki`        | `id`, `?content`, `?slug`, `version`                | Update wiki page        |
| `delete-wiki`        | `id`                                                | Delete wiki page        |
| `create-milestone`   | `project`, `name`, `start`, `finish`                | Create milestone        |
| `update-milestone`   | `id`, fields..., `version`                          | Update milestone        |
| `delete-milestone`   | `id`                                                | Delete milestone        |
| `comment`            | `entity`, `id`, `text`                              | Add comment             |
| `edit-comment`       | `entity`, `id`, `comment_id`, `text`               | Edit existing comment   |
| `delete-comment`     | `entity`, `id`, `comment_id`                       | Delete comment          |

All mutation commands require a `version` field for optimistic concurrency control. The tool returns the updated entity on success so the agent always has the latest version.

## Project Structure

```
src/
  Main.idr               CLI entry point (agent + subcommand + legacy CLI)
  Command.idr            Command sum type and dispatch table
  CLI/
    Args.idr             CLI argument data types (legacy flags)
    Help.idr             Usage/help text generation
    Output.idr           Dual-format output (text / JSON)
    Parse.idr            CLI argument parser (legacy flags + subcommands)
    Subcommand.idr       Subcommand routing and action handlers
  Model/
    Auth.idr             Token and credential types
    Common.idr           Shared types (Nat64Id, Slug, Version)
    Comment.idr          Comment/history entry
    Epic.idr             Epic record
    Issue.idr            Issue record
    Milestone.idr        Milestone record
    Project.idr          Project record
    Task.idr             Task record
    User.idr             User record
    UserStory.idr        User story record
    WikiPage.idr         Wiki page record
  Protocol/
    Request.idr          Request envelope parser
    Response.idr         Response envelope serializer
  State/
    File.idr             JSON persistence layer (workspace + global auth)
    State.idr            Workspace state model (no secrets)
    Config.idr           Static configuration (output format, etc.)
    AuthStore.idr        Token lifecycle management (global storage)
  Taiga/
    Api.idr              HTTP client wrapper (via curl subprocess)
    Auth.idr             Login, refresh, token management
    Env.idr              API environment (base URL + auth token)
    Epic.idr             Epic endpoints
    History.idr          Comment/history endpoints
    Issue.idr            Issue endpoints
    Milestone.idr        Milestone endpoints
    Project.idr          Project endpoints
    Search.idr           Search and resolver endpoints
    Task.idr             Task endpoints
    User.idr             User/member endpoints
    UserStory.idr        User story endpoints
    Wiki.idr             Wiki page endpoints
```

## Dependencies

Managed via Nix flakes. Key Idris 2 libraries:

| Library              | Usage                                        |
|----------------------|----------------------------------------------|
| `idris2-json`        | JSON parsing and serialization               |
| `idris2-elab-util`   | Deriving JSON instances via elaboration      |
| `idris2-containers`  | SortedMap / HashMap for config lookups       |
| `idris2-parser`      | Command-line argument parsing                |
| `idris2-bytestring`  | HTTP body handling                           |
| `idris2-cptr`        | C FFI bindings                               |
| `idris2-filepath`    | Config file path resolution                  |
| `idris2-refined`     | Refined types for validated IDs and slugs    |

HTTP requests are performed by shelling out to `curl` via `System.run`, avoiding the need to implement TLS and HTTP in pure Idris.

## Design Principles

1. **Token-minimal protocol** — short field names, omit nulls, arrays over objects
2. **One-shot JSON I/O** — single request per invocation, no interactive mode needed for agents
3. **Idempotent reads** — GET operations are safe to repeat
4. **OCC-aware writes** — every mutation requires `version`; tool returns updated entity
5. **Fail loudly** — structured errors with `err` code + human `msg`
6. **Deterministic output** — same input always produces same output shape
7.   **Security boundary** — workspace state (`./.taiga/`) never contains credentials
8. **Dual output** — every command produces human-readable text by default, JSON with `--json`

## Architecture

See `docs/CRUD_PLAN.md` for the full CRUD implementation plan.

## License

See [GitHub](https://github.com/gvnkd/idris2-taiga-cli) for license information.
