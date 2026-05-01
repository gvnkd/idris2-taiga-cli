# Stateful Taiga CLI — Overview

## Problem Statement

The existing `taiga-cli` is fully stateless: every invocation requires explicit authentication tokens, base URLs, and project identifiers passed either via agent-mode stdin or CLI flags. This is cumbersome for interactive use and doesn't match the workflow of tools like Terraform (workspaces), git (repos), or gh (current context).

## Vision

We want a CLI that works like this:

```bash
# Initialize local state
taiga-cli init                    # creates ./taiga/ with config

# Authenticate once, token persisted locally
taiga-cli login --user rune --pass "rune-secret-42"

# Switch context (like Terraform workspaces)
taiga-cli project set taiga        # active project is now "taiga"

# Operate on active context
taiga-cli task list                # lists tasks in active project
taiga-cli sprint show              # shows current sprint state
taiga-cli epic list                # lists epics in active project

# Any command supports --json for scripting/AI agent output
taiga-cli task list --json
```

## ⚠️ SECURITY: SENSITIVE DATA STORAGE — READ THIS FIRST ⚠️

**UNDER NO CIRCUMSTANCES SHALL ANY SECRETS (AUTH TOKENS, REFRESH TOKENS, PASSWORDS, CREDENTIALS) BE STORED IN PROJECT-DIRECTORY STATE FILES (`./taiga/`).**

Project directories are typically version-controlled with Git. Storing credentials there risks accidental commits to public repositories, leading to credential leakage and compromise of Taiga instances.

**The separation is strict and non-negotiable:**

| Data Type | Storage Location | Reason |
|-----------|-------------------|--------|
| **Credentials, tokens, refresh tokens** | `~/.local/share/taiga-cli/` (global, per-user) | Hidden directory, never tracked by Git |
| **Workspace state** (active project, base URL, cached metadata) | `./taiga/` (per-project) | Safe to commit; no secrets involved |

Concretely:
- `~/.local/share/taiga-cli/tokens/<instance_id>.json` — stores auth tokens per Taiga instance
- `~/.local/share/taiga-cli/config.json` — global user preferences
 - `./.taiga/state.json` — workspace state (project ID, sprint context, base URL reference) — **no secrets**
- `./.taiga/config.json` — per-project overrides (output format prefs, etc.) — **no secrets**

The `AppSt` record in `./taiga/state.json` will have the auth fields removed. Authentication state lives exclusively in the global directory and is linked to the workspace state only by an opaque instance identifier (a hash of the base URL).

---

## Design Principles

1. **Split storage: secrets global, state local** — Credentials live at `~/.local/share/taiga-cli/`. Workspace context (active project, sprint) lives at `./.taiga/`. This is a hard security boundary.

2. **Backward compatible** — the existing agent mode (`--stdin`) and the full `Command` dispatch table in `Command.idr` remain untouched. The new subcommand layer sits alongside it.

3. **Dual output** — every command produces human-readable text by default, and JSON when `--json` is passed. This enables both end-user workflows and AI agent / scripting automation.

4. **Stateless core preserved** — the `Taiga/*` API modules remain pure functions threaded with `ApiEnv` via auto-implicits. The new State layer sits above them, composing rather than replacing.

5. **Minimal abstraction overhead** — no monad transformers. We use straightforward IO actions and the established auto-implicit pattern already in use throughout the codebase.

## Command Structure (Subcommand Model)

```
taiga-cli <subcommand> [<action>] [args...] [--json]

Core:
  init                          Create state directory and default config
  login --user U --pass P       Authenticate, persist token
  logout                       Clear persisted token
  show                         Display current state (project, auth status)

Project context (Terraform-workspace pattern):
  project list                 List accessible projects
  project set <slug|id>        Switch active project
  project get                  Show active project details

Entity operations on active project:
  task list [--status S]       List tasks in active project
  task create <subject>        Create task
  task get <id>                Get task by ID
  task status <id> <status>    Change task status
  task comment <id> <text>     Comment on a task

  epic list                    List epics in active project
  epic get <id>                Get epic details

  sprint show                  Show current sprint state
  sprint list                  List all sprints/milestones
  sprint set <id>              Set active sprint context

  issue list                   List issues (analogous to task)
  story list                   List stories (analogous to task)
  wiki list                    List wiki pages

Global flags:
  --json                      Output JSON instead of text
  --base <url>               Override base URL for this invocation
```

## State File Layout

### Global (User-level, never committed)

```
~/.local/share/taiga-cli/
├── config.json              # Global user prefs (default output format, etc.)
└── tokens/
    └── <instance_hash>.json  # Auth token + refresh token per Taiga instance
                              # instance_hash = sha256(base_url) truncated
```

### Per-project (Safe to commit; no secrets)

```
./.taiga/
├── state.json      # Workspace state: active project, sprint context, base URL reference
└── config.json     # Per-project overrides (output format prefs, column layout)
```

The `state.json` is the mutable workspace state with **no credentials**. Auth tokens are resolved at runtime by looking up the instance hash (`sha256(base_url)`) in the global tokens directory. The `config.json` files contain only non-sensitive preferences.
