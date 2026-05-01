# Updated Test Suite Analysis (2026-05-01)

**Status:** 28 tests pass. Previous critical issues (milestone leak, stale version, hardcoded version) are fixed. New issues introduced by latest changes:

---

## 1. Bug in `client.refresh()` (Never Tested)

`conftest.py` line 70-72:
```python
def refresh(self, token):
    return self._json("refresh", {"token": token})
```

The CLI `refresh` command expects field `refresh`, not `token`:
```idris
record RefreshArgs where
  refresh : String
```

**Fix:** `{"refresh": token}`

---

## 2. `TestRefresh` Doesn't Test Refresh

```python
def test_refresh_returns_new_token(self, client):
    from conftest import _run, _assert_ok
    creds = {"username": "rune", "password": "rune-secret-42"}
    resp = _run("login", creds)
    payload = json.loads(_assert_ok(resp))
    refresh_tok = payload.get("refresh")
    assert refresh_tok is not None
```

This tests **login returns a refresh token**, not that refresh works. It never calls `client.refresh()` or the `refresh` command.

**Fix:** Use the session-scoped `auth_info` fixture (which already has the refresh token), call `client.refresh(refresh_tok)`, assert a new token is returned.

---

## 3. `TestMilestoneCRUD` Still Leaks Data

```python
def test_create_update_milestone(self, client):
    created = client.create_milestone(name)
    mid, ver1 = created["id"], created.get("version", 1)
    updated = client.update_milestone(mid, ...)
    assert "updated" in updated["name"].lower()
    # MISSING: delete milestone
```

Milestones accumulate in the project with no cleanup.

**Fix:** Wrap in `try/finally` with `client.delete_milestone(mid)` — but only if the CLI supports `delete-milestone`. If not, document the limitation.

---

## 4. Weak Error Assertions

`test_get_nonexistent_task`:
```python
resp = client._err("get-task", {"id": 99999, ...})
assert "err" in resp  # Only checks key exists
```

Could be stronger:
```python
assert resp["err"] == "not-found"  # or whatever the CLI returns
```

---

## 5. Local Imports in Test Methods

```python
def test_invalid_command_name(self, client):
    from conftest import _run  # Anti-pattern
    resp = _run("nonexistent-cmd", {}, client.token)
```

Importing from conftest inside a test method is unusual. `_run` should either be module-level or the client should have a method for raw calls.

**Fix:** Add `client._raw_cmd(cmd, args)` or import `_run` at module level.

---

## 6. `_ts()` Still Duplicated 9 Times

Every CRUD class repeats:
```python
def _ts(self): return str(int(time.time()))
```

**Fix:** Extract to module-level:
```python
def _ts() -> str:
    return str(int(time.time()))
```

---

## 7. `client.refresh()` Never Called in Tests

The `refresh` method exists on `TaigaClient` but no test exercises it. Combined with the field-name bug (item 1), this means the method is completely untested and broken.

---

## Summary Table

| Issue | File | Severity | Effort |
|---|---|---|---|
| `refresh()` sends wrong field name (`token` vs `refresh`) | `conftest.py` | **High** (latent bug) | 1 min |
| `TestRefresh` doesn't test refresh endpoint | `test_taiga_cli.py` | **High** (false confidence) | 5 min |
| Milestone test leaks data | `test_taiga_cli.py` | **Medium** | 2 min |
| Weak error assertions | `test_taiga_cli.py` | **Low** | 5 min |
| Local imports in test methods | `test_taiga_cli.py` | **Low** | 2 min |
| `_ts()` duplicated | `test_taiga_cli.py` | **Low** | 2 min |
| `refresh()` method untested | `conftest.py` + tests | **Medium** | 5 min |
