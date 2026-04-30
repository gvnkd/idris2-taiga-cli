# taiga-cli

A command-line tool written in [Idris 2](https://github.com/idris-lang/Idris2) that lets AI agents interact with a [Taiga](https://taiga.io) project management instance over its REST API.

It exposes a compact JSON-over-stdin/stdout protocol so an agent can authenticate, query, create, and edit Taiga entities with minimal token overhead.

## Features

- **Agent mode** (default): reads one JSON request from stdin, dispatches the command, writes one JSON response to stdout
- **CLI mode**: human-friendly flags (`--list-epics`, `--login`, etc.) with plain JSON output
- Full CRUD for epics, user stories, tasks, issues, wiki pages, and milestones
- Comment management via the Taiga history API
- Global project search and entity resolution by slug/ref
- Token-minimal compact JSON protocol
- OCC (optimistic concurrency control) version handling on all mutations
- Structured error responses with error codes and messages

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

### CLI Mode

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
echo '{"cmd":"login","args":{"username":"admin","password":"1234"},"base":"http://127.0.0.1:8000/api/v1"}' \
  | taiga-cli --stdin

# List projects
echo '{"cmd":"list-projects","auth":{"token":"eyJ..."},"base":"http://127.0.0.1:8000/api/v1"}' \
  | taiga-cli --stdin

# Create a task
echo '{"cmd":"create-task","args":{"project":"backend","subject":"Fix auth bug","story":42},"auth":{"token":"eyJ..."},"base":"http://127.0.0.1:8000/api/v1"}' \
  | taiga-cli --stdin
```

## JSON Protocol

### Request

```json
{
  "cmd":   "<command>",
  "args":  { },
  "auth":  { "token": "..." },
  "base":  "http://127.0.0.1:8000/api/v1"
}
```

| Field  | Required  | Description                                                |
|--------|-----------|------------------------------------------------------------|
| `cmd`  | yes       | Command name, e.g. `"login"`, `"list-projects"`           |
| `args` | per-cmd   | Command-specific parameters                                |
| `auth` | most cmds | `{"token":"..."}` or `{"username":"...","password":"..."}` |
| `base` | no        | Taiga API base URL (default from env `TAIGA_URL`)          |

### Response

Success:

```json
{"ok": true, "data": { }}
```

Error:

```json
{"ok": false, "err": "not-found", "msg": "Project 42 not found"}
```

## Command Reference

### Authentication

| cmd       | args                          | description                       |
|-----------|-------------------------------|-----------------------------------|
| `login`   | `{"username":"...","password":"..."}` | Exchange credentials for token |
| `refresh` | `{"refresh":"..."}`           | Refresh an expiring token         |
| `me`      | —                             | Get current user profile          |

### Read Operations

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

### Write Operations

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
| `comment`            | `entity`, `id`, `text`                              | Add comment             |
| `edit-comment`       | `entity`, `id`, `comment_id`, `text`               | Edit existing comment   |
| `delete-comment`     | `entity`, `id`, `comment_id`                       | Delete comment          |

All mutation commands require a `version` field for optimistic concurrency control. The tool returns the updated entity on success so the agent always has the latest version.

## Project Structure

```
src/
  Main.idr               CLI entry point (agent mode + CLI mode)
  Command.idr            Command sum type and dispatch table
  CLI/
    Args.idr             CLI argument data types
    Help.idr             Usage/help text generation
    Parse.idr            CLI argument parser
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

## License

See [GitHub](https://github.com/gvnkd/idris2-taiga-cli) for license information.
