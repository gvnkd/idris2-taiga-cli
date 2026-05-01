# Taiga CLI Full CRUD Implementation Plan

## 1. Current State

### Agent Mode (stdin JSON protocol) — COMPLETE
The agent mode already supports full CRUD for all entities via the `Command.idr` dispatch table:

| Entity    | List | Get | Create | Update | Delete | Other               |
|-----------|------|-----|--------|--------|--------|---------------------|
| Project   | ✅   | ✅  | ❌     | ❌     | ❌     | —                   |
| Epic      | ✅   | ✅  | ✅     | ✅     | ✅     | —                   |
| Story     | ✅   | ✅  | ✅     | ✅     | ✅     | —                   |
| Task      | ✅   | ✅  | ✅     | ✅     | ✅     | status, comment     |
| Issue     | ✅   | ✅  | ✅     | ✅     | ✅     | —                   |
| Wiki      | ✅   | ✅  | ✅     | ✅     | ✅     | —                   |
| Milestone | ✅   | ❌  | ✅     | ✅     | ✅     | —                   |
| Comment   | ✅   | ❌  | ✅     | ✅     | ✅     | via history API     |
| Search    | ✅   | —   | —      | —      | —      | resolve             |
| User      | ✅   | ❌  | ❌     | ❌     | ❌     | memberships, roles  |

### Subcommand CLI Mode — PARTIAL
The subcommand CLI (`taiga-cli <verb> <action>`) currently supports only read operations and a handful of writes:

| Entity    | List | Get | Create | Update | Delete | Other |
|-----------|------|-----|--------|--------|--------|-------|
| Project   | ✅   | ✅  | ❌     | ❌     | ❌     | set   |
| Epic      | ✅   | ✅  | ❌     | ❌     | ❌     | —     |
| Story     | ✅   | ✅  | ❌     | ❌     | ❌     | —     |
| Task      | ✅   | ✅  | ✅     | ❌     | ❌     | status, comment |
| Issue     | ✅   | ✅  | ❌     | ❌     | ❌     | —     |
| Wiki      | ✅   | ✅  | ❌     | ❌     | ❌     | —     |
| Milestone | ✅   | ❌  | ❌     | ❌     | ❌     | set   |
| Comment   | ❌   | ❌  | ❌     | ❌     | ❌     | —     |

## 2. Goal

Bring subcommand CLI to **full CRUD parity** with agent mode. Users should be able to create, read, update, and delete every entity type from the command line using intuitive subcommands.

## 3. Design Principles

1. **Ref-first identifiers** — All entity lookups accept ref IDs (user-facing numbers) per issue 330. Raw DB IDs still work for backward compatibility.

2. **Active project context** — Project-scoped commands (create, list) use the active project set via `project set <slug>`. No need to pass `--project` on every command.

3. **OCC handled internally** — Update/delete operations fetch the current version automatically. Users never need to know about version numbers in subcommand mode.

4. **Consistent argument patterns** — Same flag names and positional arg conventions across all entity types.

5. **Global `--json` flag** — All commands respect `--json` for machine-readable output (already implemented).

6. **Fail fast with clear messages** — Missing active project, unknown refs, and permission errors produce human-readable errors.

## 4. Command Specification

### 4.1 Global Flags (applicable to all commands)

```
--json          Output raw JSON instead of human-readable text
```

### 4.2 Project Commands

```bash
# Read (exists)
taiga-cli project list
taiga-cli project get
taiga-cli project set <slug-or-id>

# Create (NEW)
taiga-cli project create <name> [--slug SLUG] [--description DESC]
  → POST /projects
  → Args: name (required), slug (optional, auto-generated), description (optional)

# Update (NEW)
taiga-cli project update <slug-or-id> [--name NAME] [--description DESC]
  → PATCH /projects/<id>
  → Auto-fetches current version for OCC

# Delete (NEW — admin only)
taiga-cli project delete <slug-or-id>
  → DELETE /projects/<id>
  → Confirmation prompt: "Delete project 'Name' and all its data? (yes/no)"
```

### 4.3 Epic Commands

```bash
# Read (exists)
taiga-cli epic list
taiga-cli epic get <id-or-ref>

# Create (NEW)
taiga-cli epic create <subject> [--description DESC] [--status STATUS]
  → POST /epics
  → Uses active project

# Update (NEW)
taiga-cli epic update <id-or-ref> [--subject SUBJ] [--description DESC] [--status STATUS]
  → PATCH /epics/<id>
  → Auto-fetches version

# Delete (NEW)
taiga-cli epic delete <id-or-ref>
  → DELETE /epics/<id>
```

### 4.4 Story (User Story) Commands

```bash
# Read (exists)
taiga-cli story list
taiga-cli story get <id-or-ref>

# Create (NEW)
taiga-cli story create <subject> [--description DESC] [--milestone MILESTONE_ID]
  → POST /userstories
  → Uses active project

# Update (NEW)
taiga-cli story update <id-or-ref> [--subject SUBJ] [--description DESC] [--milestone MILESTONE]
  → PATCH /userstories/<id>

# Delete (NEW)
taiga-cli story delete <id-or-ref>
  → DELETE /userstories/<id>
```

### 4.5 Task Commands

```bash
# Read / partial write (exists)
taiga-cli task list [--status STATUS]
taiga-cli task get <id-or-ref>
taiga-cli task create <subject>
taiga-cli task status <id-or-ref> <status-id>
taiga-cli task comment <id-or-ref> <text>

# Update (NEW)
taiga-cli task update <id-or-ref> [--subject SUBJ] [--description DESC] [--status STATUS]
  → PATCH /tasks/<id>

# Delete (NEW)
taiga-cli task delete <id-or-ref>
  → DELETE /tasks/<id>
```

### 4.6 Issue Commands

```bash
# Read (exists)
taiga-cli issue list
taiga-cli issue get <id-or-ref>

# Create (NEW)
taiga-cli issue create <subject> [--description DESC] [--priority PRIO] [--severity SEV] [--type TYPE]
  → POST /issues
  → Uses active project

# Update (NEW)
taiga-cli issue update <id-or-ref> [--subject SUBJ] [--description DESC] [--type TYPE]
  → PATCH /issues/<id>

# Delete (NEW)
taiga-cli issue delete <id-or-ref>
  → DELETE /issues/<id>
```

### 4.7 Wiki Commands

```bash
# Read (exists)
taiga-cli wiki list
taiga-cli wiki get <id-or-ref>

# Create (NEW)
taiga-cli wiki create <slug> <content>
  → POST /wiki
  → Uses active project

# Update (NEW)
taiga-cli wiki update <id-or-ref> [--content CONTENT] [--slug SLUG]
  → PATCH /wiki/<id>

# Delete (NEW)
taiga-cli wiki delete <id-or-ref>
  → DELETE /wiki/<id>
```

### 4.8 Sprint / Milestone Commands

```bash
# Read / partial write (exists)
taiga-cli sprint list
taiga-cli sprint show
taiga-cli sprint set <id-or-ref>

# Create (NEW)
taiga-cli sprint create <name> [--start YYYY-MM-DD] [--end YYYY-MM-DD]
  → POST /milestones
  → Defaults: start=today, end=today+14

# Update (NEW)
taiga-cli sprint update <id-or-ref> [--name NAME] [--start DATE] [--end DATE]
  → PATCH /milestones/<id>

# Delete (NEW)
taiga-cli sprint delete <id-or-ref>
  → DELETE /milestones/<id>
```

### 4.9 Comment Commands (NEW)

```bash
# Add comment to any entity
taiga-cli comment add <entity> <id-or-ref> <text>
  → entity ∈ {task, issue, story, epic, wiki}
  → POST /history/<entity>/<id>

# List comments
taiga-cli comment list <entity> <id-or-ref>
  → GET /history/<entity>/<id>

# Edit comment (by comment ID)
taiga-cli comment edit <entity> <id-or-ref> <comment-id> <new-text>
  → PATCH /history/<entity>/<id>/edit_comment

# Delete comment
taiga-cli comment delete <entity> <id-or-ref> <comment-id>
  → PATCH /history/<entity>/<id>/delete_comment
```

## 5. Implementation Architecture

### 5.1 Files to Modify

| File | Changes |
|------|---------|
| `src/CLI/Parse.idr` | Add parseAction clauses for all new subcommands |
| `src/CLI/Subcommand.idr` | Add Action constructors, handler functions, dispatch |
| `src/CLI/Output.idr` | Add confirmation prompt helper, success messages |
| `tests/test_taiga_cli.py` | Add CRUD tests for every entity |

### 5.2 Pattern for Adding a New Command

Example: adding `epic create`.

**Step 1:** Add Action constructor in `CLI.Subcommand.idr`:
```idris
ActEpicCreate : String -> Maybe String -> Maybe String -> Action
```

**Step 2:** Add parse clause in `CLI.Parse.idr`:
```idris
parseAction ("epic" :: "create" :: subj :: rest) =
  let desc  := findFlag "--description" rest
      status := findFlag "--status" rest
   in Right $ ActEpicCreate subj desc status
```

**Step 3:** Add handler in `CLI.Subcommand.idr`:
```idris
handleEpicCreate : String -> Maybe String -> Maybe String -> IO (Either String CmdResult)
handleEpicCreate subject mDesc mStatus = do
  st_e <- loadState
  case st_e of
    Left err => pure $ Left err
    Right st => do
      case getActiveProject st of
        Left err => pure $ Left err
        Right pid => do
          env_e <- resolveApiEnv
          case env_e of
            Left err => pure $ Left err
            Right env =>
              callToResult "Epic created" $
                createEpic @{env} (show pid.id) subject mDesc mStatus
```

**Step 4:** Add dispatch in `executeAction`:
```idris
executeAction (ActEpicCreate subj d s) = handleEpicCreate subj d s
```

**Step 5:** Add test in `tests/test_taiga_cli.py`.

### 5.3 Update Pattern (OCC Auto-Resolution)

All update handlers follow the same pattern:

1. Resolve the identifier to a `Nat64Id`
2. **Fetch the entity to get current version**
3. Build the PATCH payload with only changed fields
4. Call the update API with the fetched version
5. Return the updated entity

```idris
handleEpicUpdate : String -> Maybe String -> Maybe String -> Maybe String -> IO (Either String CmdResult)
handleEpicUpdate ident mSubject mDesc mStatus = do
  id_e <- resolveToId ident
  case id_e of
    Left err => pure $ Left err
    Right nid => do
      env_e <- resolveApiEnv
      case env_e of
        Left err => pure $ Left err
        Right env => do
          -- Fetch current to get version
          current_e <- getEpic @{env} nid
          case current_e of
            Left err => pure $ Left err
            Right current =>
              let ver := current.version
                  subj := fromMaybe current.subject mSubject
                  desc := fromMaybe current.description mDesc
                  stat := fromMaybe current.status mStatus
               in callToResult "Epic updated" $
                    updateEpic @{env} nid (Just subj) (Just desc) (Just stat) ver
```

### 5.4 Delete Pattern

Delete operations should show a confirmation prompt when running interactively (TTY), but skip it when piped (for scripting):

```idris
handleEpicDelete : String -> IO (Either String CmdResult)
handleEpicDelete ident = do
  id_e <- resolveToId ident
  case id_e of
    Left err => pure $ Left err
    Right nid => do
      env_e <- resolveApiEnv
      case env_e of
        Left err => pure $ Left err
        Right env => do
          -- Optional: fetch name for confirmation message
          confirmed <- confirmDelete "epic" ident
          if not confirmed
            then pure $ Right $ cmdInfo "Delete cancelled"
            else callToResult "Epic deleted" $
                   map (const "deleted") $ deleteEpic @{env} nid
```

## 6. Testing Strategy

### 6.1 Test Organization

Extend `tests/test_taiga_cli.py` with new test classes:

```python
class TestEpicCRUDSubcommand:
    """Epic CRUD via subcommand CLI."""
    
    def test_create_epic(self, workspace):
        self._login(workspace)
        self._set_project(workspace)
        proc = subprocess.run(
            [BIN, "epic", "create", "pytest epic subcmd"],
            ...
        )
        assert proc.returncode == 0
        data = json.loads(proc.stdout.split("\n", 1)[1])
        assert data["subject"] == "pytest epic subcmd"
        # cleanup
        
    def test_update_epic(self, workspace):
        # create first, then update by ref
        
    def test_delete_epic(self, workspace):
        # create first, then delete by ref
```

Repeat for: `TestStoryCRUDSubcommand`, `TestTaskCRUDSubcommand`, `TestIssueCRUDSubcommand`, `TestWikiCRUDSubcommand`, `TestMilestoneCRUDSubcommand`, `TestCommentSubcommand`.

### 6.2 Test Coverage Matrix

| Command | Create | Get by Ref | Update | Delete |
|---------|--------|-----------|--------|--------|
| epic    | ✅ | ✅ | ✅ | ✅ |
| story   | ✅ | ✅ | ✅ | ✅ |
| task    | ✅ | ✅ | ✅ | ✅ |
| issue   | ✅ | ✅ | ✅ | ✅ |
| wiki    | ✅ | ✅ | ✅ | ✅ |
| sprint  | ✅ | ✅ | ✅ | ✅ |
| comment | ✅ | ✅ | ✅ | ✅ |

## 7. Implementation Phases

### Phase 1: Foundation (1-2 days)
- Add `confirmDelete` helper to `CLI.Output.idr`
- Add `findFlag` helper to `CLI.Parse.idr` for `--key value` parsing
- Refactor `handleTaskCreate` to serve as the template pattern
- Add `fromMaybe` utility if not present

### Phase 2: Core Entities — Task, Issue, Epic, Story (2-3 days)
- **Task**: update, delete
- **Issue**: create, update, delete
- **Epic**: create, update, delete
- **Story**: create, update, delete

These share the same pattern (subject, description, status/milestone). High value — most common operations.

### Phase 3: Wiki & Milestone (1 day)
- **Wiki**: create, update, delete
- **Milestone/Sprint**: create, update, delete

### Phase 4: Comments & Polish (1 day)
- **Comment**: add, list, edit, delete
- Add `--force` flag to delete commands (bypass confirmation)
- Improve error messages for missing active project

### Phase 5: Project Admin (optional, 1 day)
- **Project**: create, update, delete (admin-only, lower priority)

## 8. Edge Cases & Error Handling

| Scenario | Handling |
|----------|----------|
| No active project set | Clear error: "No active project. Run 'taiga-cli project set <slug>' first." |
| Ref not found in project | "Ref 123 not found in active project" |
| Update with no changes | Skip API call, return "No changes made" |
| Delete non-existent entity | 404 from API → "Entity not found" |
| Delete without permission | 403 → "Permission denied" |
| TTY delete confirmation | Prompt "Delete 'Subject'? (yes/no)" |
| Piped delete | Auto-confirm (no TTY) |
| OCC conflict on update | Auto-retry once after re-fetching version |

## 9. Open Questions

1. **Project create/update/delete** — Should these be in scope? Project creation requires more fields (is_private, etc.) and is usually a one-time admin operation. Defer to Phase 5.

2. **Batch operations** — Should we support `taiga-cli task delete 1 2 3` or bulk create from JSON/CSV? Out of scope for initial CRUD.

3. **Attachment handling** — File uploads (task attachments, epic covers) require multipart/form-data. Out of scope.

4. **Custom attributes** — Taiga supports custom fields per project. Out of scope for initial implementation.

## 10. Summary

The agent mode already has the complete API layer. The subcommand CLI needs:

- **22 new Action constructors** across 7 entity types
- **~30 new parseAction clauses** in `CLI.Parse.idr`
- **~30 new handler functions** in `CLI.Subcommand.idr`
- **~42 new test cases** in `tests/test_taiga_cli.py`

Estimated effort: **5-7 days** following the phased approach above.
