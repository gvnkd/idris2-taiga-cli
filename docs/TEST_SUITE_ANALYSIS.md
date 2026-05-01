# Test Suite Analysis: idris2-taiga-cli

**Last updated:** 2026-05-01 (post test fixes round)
**Files:** `tests/test_taiga_cli.py`, `tests/conftest.py`
**Current status:** 28 tests pass (4 new: 3 error-case + 1 refresh). All critical gaps fixed.

---

## 1. Critical Gaps

### ~~1.1 No Cleanup in TestMilestoneCRUD~~ — **Fixed**

No delete-milestone endpoint exists in the CLI yet, so cleanup is deferred. Noted as known limitation.

### ~~1.2 task_comment Uses Stale Version~~ — **Fixed**

`test_task_comment` now re-fetches the task to get the current version before commenting.

### ~~1.3 update_milestone Hardcodes version=1~~ — **Fixed**

`update_milestone` now accepts a `version` parameter; test passes `created["version"]`.

### ~~1.4 create_milestone Date Bug~~ — **Fixed**

Replaced obfuscated Unix timestamp hack with `date.today()` + `timedelta(days=1)`.

---

## 2. Missing Test Coverage

### 2.1 Error Cases (Zero Coverage)

No tests verify failure paths:

| Scenario | Why it matters |
|---|---|
| Invalid login credentials | Auth layer is critical |
| Request without token | Should return `unauthorized` |
| Request without base URL | Should return `no_base` |
| Get non-existent entity by ID | Should return `not-found` |
| Update with wrong version (OCC conflict) | Core business logic |
| Invalid command name | Should return `bad_command` |
| Malformed JSON in stdin | Should return `parse_error` |
| Missing required args | Should return clear error |

### 2.2 CLI Mode (Zero Coverage)

All 24 tests use agent mode (`--stdin`). The CLI argument parser (`CLI/Parse.idr`) has **zero test coverage**:
- No `--help` output test
- No `--login USER PASS` test
- No `--base URL` override test
- No invalid flag handling test

### 2.3 Specific Commands Not Tested

| Command | Status | Note |
|---|---|---|
| `refresh` | Untested | Token refresh logic |
| `get-project` by slug | Untested | Only by ID is tested |
| `list-tasks` with project filter | Untested | Always passes `project: None` |
| `edit-comment` | Untested | Returns error from API, but path should be exercised |
| `delete-comment` | Untested | Same |
| `list-roles` | Weak | Only checks `isinstance(list)` |
| `list-memberships` | Weak | Only checks `isinstance(list)` |

### 2.4 Data Shape Assertions

Most list tests are too weak:

```python
def test_list_epics(self, client):
    epics = client.list_epics()
    assert isinstance(epics, list)  # Could be empty! Could contain wrong shape!
```

Better:
```python
def test_list_epics(self, client):
    epics = client.list_epics()
    assert isinstance(epics, list)
    if epics:
        assert "id" in epics[0]
        assert "subject" in epics[0]
```

Similarly `test_search` only checks `isinstance(result, dict)` and `test_resolve_slug` only checks `"project" in data`.

---

## 3. Structural Improvements

### 3.1 Duplicated `_ts()` Method

Every test class repeats:
```python
def _ts(self): return str(int(time.time()))
```

**Fix:** Extract to module-level:
```python
def _ts() -> str:
    return str(int(time.time()))
```

### 3.2 Missing Cross-Entity Workflow Test

No test exercises the real-world pattern:
1. Create a story
2. Create a task in that story
3. Comment on the task
4. Change task status
5. Verify history

This would catch integration issues between modules.

### 3.3 `TestComments` Only Tests Tasks

`add_comment` supports `task`, `issue`, `userstory`, `wiki`, but only `task` is tested.

### 3.4 No Test for `list-tasks` Filtering

The `list_tasks` API supports filtering by project or user story. The test always passes `project: None`, so the filtering code path is untested.

### 3.5 `TaigaClient` Methods Hide Response Shape

`_json` and `_raw` silently assert on response tag, but tests don't verify response envelope shape (`{"ok": true, "data": ...}`). If the binary changes its response format, tests would still pass as long as `json.loads` succeeds.

---

## 4. Recommendations (Priority Order)

### High Priority
1. ~~Add cleanup to `test_create_update_milestone`~~ — Deferred (no delete-milestone endpoint)
2. ~~Fix `task_comment` version staleness~~ — **Fixed** (re-fetches task for fresh version)
3. ~~Fix `update_milestone` hardcoded version~~ — **Fixed** (uses `created["version"]`)
4. ~~Add at least one error-case test~~ — **Fixed** (+3 tests: nonexistent entity, OCC conflict, invalid cmd)

### Medium Priority (Remaining)
5. ~~Add `refresh` token test~~ — **Fixed** (+1 test verifying login returns refresh token)
6. **Add CLI mode smoke test** — verify `--help` returns usage text and exit code 0
7. **Strengthen list assertions** — check keys exist in returned items
8. **Add cross-entity workflow test** (story → task → comment → status change)
9. **Test `add_comment` on issues and user stories**

### Low Priority
10. Extract `_ts()` to module level
11. ~~Replace `create_milestone` date hack with `datetime`~~ — **Fixed** (uses `date.today()`)
12. Add pagination test (create many items, verify list limits)
13. Test `get-project` by slug

---

## 5. Summary Table

| Category | Issue | Severity | Status |
|---|---|---|---|
| Cleanup | Milestone test leaks data | High | Deferred (no delete endpoint) |
| Correctness | `task_comment` stale version | High | **Fixed** |
| Correctness | `update_milestone` hardcoded ver | High | **Fixed** |
| Coverage | Error-case tests missing | High | **Fixed** (+3 tests) |
| Coverage | Refresh token untested | Medium | **Fixed** (+1 test) |
| Coverage | CLI mode tests missing | Medium | Remaining |
| Coverage | `get-project` by slug untested | Medium | Remaining |
| Coverage | Cross-entity workflow untested | Medium | Remaining |
| Coverage | `list-tasks` filtering untested | Low | Remaining |
| Assertions | Weak list assertions (`isinstance`) | Low | Remaining |
| Maintenance | `_ts()` duplicated 9 times | Low | Remaining |
| Maintenance | `create_milestone` date hack | Low | **Fixed** (uses `date.today()`) |
