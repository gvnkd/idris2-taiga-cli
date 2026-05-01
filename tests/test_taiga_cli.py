import json
import time
import pytest

from conftest import _run, PROJECT_ID


def _ts():
    return str(int(time.time()))


class TestAuth:
    def test_me(self, client):
        user = client.me()
        assert user["username"] == "rune"

    def test_list_projects(self, client):
        projects = client.list_projects()
        slugs = [p["slug"] for p in projects]
        assert "test-project" in slugs

    def test_get_project_by_id(self, client):
        proj = client.get_project_by_id(int(PROJECT_ID))
        assert proj["id"] == int(PROJECT_ID)
        assert proj["slug"] == "test-project"


class TestErrors:
    """Error-case tests — verify failure paths return proper errors."""

    def test_get_nonexistent_task(self, client):
        err = client._err("get-task", {"id": 99999, "maybeNat64ArgsTag": ""})
        assert "err" in err
        assert "msg" in err

    def test_update_wrong_version_occ_conflict(self, client):
        """Update with wrong version should fail (OCC conflict)."""
        created = client._json("create-task", {
            "project": PROJECT_ID, "subject": f"occ test {_ts()}",
            "story": None, "description": None,
            "status": None, "milestone": None,
        })
        tid = created["id"]
        try:
            err = client._err("update-task", {
                "id": tid, "subject": "fail update",
                "description": None, "status": None,
                "version": 99999,
            })
            assert "err" in err
            assert "msg" in err
        finally:
            client.delete_task(tid)

    def test_invalid_command_name(self, client):
        resp = _run("nonexistent-cmd", {}, client.token)
        assert resp["tag"] == "Err"
        assert "err" in resp["contents"]


class TestRefresh:
    """Token refresh tests."""

    def test_refresh_returns_new_token(self, client):
        from conftest import _assert_ok
        # Get the original login response to extract refresh token
        creds = {"username": "rune", "password": "rune-secret-42"}
        resp = _run("login", creds)
        payload = json.loads(_assert_ok(resp))
        refresh_tok = payload.get("refresh")
        assert refresh_tok is not None, "Login should return a refresh token"

        # Call refresh endpoint and verify we get a new auth token
        result = client.refresh(refresh_tok)
        assert "auth_token" in result, f"Refresh should return auth_token, got: {result}"
        assert result["auth_token"] != payload["auth_token"], "Refresh should return a new token"


class TestEpicCRUD:
    def test_list_epics(self, client):
        epics = client.list_epics()
        assert isinstance(epics, list)

    def test_create_get_update_delete_epic(self, client):
        ts = _ts()
        subject = f"pytest epic {ts}"
        created = client.create_epic(subject)
        eid, ver1 = created["id"], created["version"]
        try:
            fetched = client.get_epic(eid)
            assert fetched["id"] == eid

            updated = client.update_epic(eid, subject="Updated Epic", version=ver1)
            assert updated["subject"] == "Updated Epic"
        finally:
            client.delete_epic(eid)


class TestStoryCRUD:
    def test_list_stories(self, client):
        assert isinstance(client.list_stories(), list)

    def test_create_get_update_delete_story(self, client):
        ts = _ts()
        subject = f"pytest story {ts}"
        created = client.create_story(subject)
        sid, ver1 = created["id"], created["version"]
        try:
            fetched = client.get_story(sid)
            assert fetched["id"] == sid

            updated = client.update_story(sid, subject="Updated Story", version=ver1)
            assert updated["subject"] == "Updated Story"
        finally:
            client.delete_story(sid)


class TestTaskCRUD:
    def test_list_tasks(self, client):
        assert isinstance(client.list_tasks(), list)

    def test_create_get_update_delete_task(self, client):
        ts = _ts()
        subject = f"pytest task {ts}"
        created = client.create_task(subject)
        tid, ver1 = created["id"], created["version"]
        try:
            fetched = client.get_task(tid)
            assert fetched["id"] == tid

            updated = client.update_task(tid, subject="Updated Task", version=ver1)
            assert updated["subject"] == "Updated Task"
        finally:
            client.delete_task(tid)


class TestTaskSpecial:
    def _ts(self): return str(int(time.time()))

    @pytest.fixture
    def task_id(self, client):
        ts = _ts()
        t = client.create_task(f"pytest special {ts}")
        yield (t["id"], t["version"])
        client.delete_task(t["id"])

    def test_watch_task(self, client, task_id):
        tid, _ = task_id
        watched = client.watch_task(tid)
        assert watched["id"] == tid

    def test_change_task_status(self, client, task_id):
        """change-task-status: OCC expects CURRENT version (no increment needed)."""
        tid, ver = task_id
        # Status 41 = "New" in test-project (project 13)
        result = client.change_task_status(tid, 41, ver)
        assert result["status"] == 41

    def test_task_comment(self, client, task_id):
        """task-comment uses raw response (not JSON)."""
        tid, _ = task_id
        # Fetch fresh version — prior tests may have mutated the task
        fresh = client.get_task(tid)
        ver = fresh["version"]
        result = client.task_comment(tid, "pytest comment", ver)
        assert "comment" in result.lower()


class TestIssueCRUD:
    def test_list_issues(self, client):
        assert isinstance(client.list_issues(), list)

    def test_create_get_update_delete_issue(self, client):
        ts = _ts()
        subject = f"pytest issue {ts}"
        created = client.create_issue(subject)
        iid, ver1 = created["id"], created.get("version", 1)
        try:
            fetched = client.get_issue(iid)
            assert fetched["id"] == iid

            updated = client.update_issue(iid, subject="Updated Issue", version=ver1)
            assert updated["subject"] == "Updated Issue"
        finally:
            client.delete_issue(iid)


class TestWikiCRUD:
    def test_list_wiki(self, client):
        assert isinstance(client.list_wiki(), list)

    def test_create_get_update_delete_wiki(self, client):
        ts = _ts()
        slug = f"pytest-wiki-{ts}"
        created = client.create_wiki(slug, "initial content")
        wid, ver1 = created["id"], created["version"]
        try:
            fetched = client.get_wiki(wid)
            assert fetched["id"] == wid

            updated = client.update_wiki(wid, content="updated content", version=ver1)
            assert updated["content"] == "updated content"
        finally:
            client.delete_wiki(wid)


class TestMilestoneCRUD:
    def test_list_milestones(self, client):
        assert isinstance(client.list_milestones(), list)

    def test_create_update_delete_milestone(self, client):
        ts = _ts()
        name = f"pytest milestone {ts}"
        created = client.create_milestone(name)
        mid, ver1 = created["id"], created.get("version", 1)
        try:
            updated = client.update_milestone(mid, name=f"{name} updated", version=ver1)
            assert "updated" in updated["name"].lower()
        finally:
            client.delete_milestone(mid)


class TestComments:
    def test_comment_and_list(self, client):
        ts = _ts()
        t = client.create_task(f"pytest comment target {ts}")
        tid = t["id"]
        try:
            client.add_comment("task", tid, "hello from pytest")
            history = client.list_comments("task", tid)
            assert isinstance(history, list)
        finally:
            client.delete_task(tid)


class TestSearchResolve:
    def test_search(self, client):
        result = client.search("test")
        assert isinstance(result, dict)

    def test_resolve_slug(self, client):
        data = client.resolve("1")
        assert "project" in data


class TestUsersMembershipsRoles:
    def test_list_users(self, client):
        users = client.list_users()
        assert isinstance(users, list)

    def test_list_memberships(self, client):
        members = client.list_memberships()
        assert isinstance(members, list)

    def test_list_roles(self, client):
        roles = client.list_roles()
        assert isinstance(roles, list)
