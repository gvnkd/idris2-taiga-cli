import json
import os
import subprocess
import time
import pytest

from conftest import BIN, _run, PROJECT_ID


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


class TestStateful:
    """Test the stateful subcommand mode (init, login, project set, etc.)."""

    BASE = "http://127.0.0.1:8000/api/v1"

    @staticmethod
    def _token_file():
        """Path to the global token file for the test base URL."""
        home = os.path.expanduser("~")
        # instanceHash replaces non-alnum/-/. with underscores
        return os.path.join(home, ".local", "share", "taiga-cli", "tokens",
                            "http___127.0.0.1_8000_api_v1.json")

    @pytest.fixture
    def workspace(self, tmp_path):
        """Create a fresh workspace, init, and clean up tokens afterwards."""
        tf = self._token_file()
        if os.path.exists(tf):
            os.remove(tf)

        proc = subprocess.run(
            [BIN, "init", self.BASE],
            capture_output=True, text=True, timeout=30,
            cwd=str(tmp_path),
        )
        assert proc.returncode == 0, f"init failed: {proc.stdout}{proc.stderr}"

        yield tmp_path

        if os.path.exists(tf):
            os.remove(tf)

    def test_init_creates_taiga_dir(self, workspace):
        state_file = workspace / ".taiga" / "state.json"
        assert state_file.exists()
        data = json.loads(state_file.read_text())
        assert data["base_url"] == self.BASE

    def test_login_piped_password(self, workspace):
        proc = subprocess.run(
            [BIN, "login", "--user", "rune"],
            input="rune-secret-42\n",
            capture_output=True, text=True, timeout=30,
            cwd=str(workspace),
        )
        assert proc.returncode == 0, f"login failed: {proc.stdout}{proc.stderr}"
        assert "Authenticated successfully" in proc.stdout
        assert os.path.exists(self._token_file())

    def test_login_password_shows_warning(self, workspace):
        proc = subprocess.run(
            [BIN, "login", "--user", "rune", "--password", "rune-secret-42"],
            capture_output=True, text=True, timeout=30,
            cwd=str(workspace),
        )
        assert proc.returncode == 0
        assert "WARNING" in proc.stdout
        assert "insecure" in proc.stdout

    def test_show_after_init(self, workspace):
        proc = subprocess.run(
            [BIN, "show"],
            capture_output=True, text=True, timeout=30,
            cwd=str(workspace),
        )
        assert proc.returncode == 0
        assert self.BASE in proc.stdout
        assert "(none)" in proc.stdout

    def test_full_workflow(self, workspace):
        # Login with piped password
        proc = subprocess.run(
            [BIN, "login", "--user", "rune"],
            input="rune-secret-42\n",
            capture_output=True, text=True, timeout=30,
            cwd=str(workspace),
        )
        assert proc.returncode == 0

        # Set active project by ID
        proc = subprocess.run(
            [BIN, "project", "set", PROJECT_ID],
            capture_output=True, text=True, timeout=30,
            cwd=str(workspace),
        )
        assert proc.returncode == 0
        assert "Active project set to" in proc.stdout

        # Show reflects active project
        proc = subprocess.run(
            [BIN, "show"],
            capture_output=True, text=True, timeout=30,
            cwd=str(workspace),
        )
        assert proc.returncode == 0
        assert "Active project:" in proc.stdout
        assert "13" in proc.stdout

        # List tasks in active project
        proc = subprocess.run(
            [BIN, "task", "list"],
            capture_output=True, text=True, timeout=30,
            cwd=str(workspace),
        )
        assert proc.returncode == 0
        assert "[OK]" in proc.stdout

        # List sprints in active project
        proc = subprocess.run(
            [BIN, "sprint", "list"],
            capture_output=True, text=True, timeout=30,
            cwd=str(workspace),
        )
        assert proc.returncode == 0
        assert "[OK]" in proc.stdout


class TestRefResolution:
    """Test ref-based resolution in subcommand CLI mode (issue 330)."""

    BASE = "http://127.0.0.1:8000/api/v1"

    @staticmethod
    def _token_file():
        home = os.path.expanduser("~")
        return os.path.join(home, ".local", "share", "taiga-cli", "tokens",
                            "http___127.0.0.1_8000_api_v1.json")

    @pytest.fixture
    def workspace(self, tmp_path):
        tf = self._token_file()
        if os.path.exists(tf):
            os.remove(tf)

        proc = subprocess.run(
            [BIN, "init", self.BASE],
            capture_output=True, text=True, timeout=30,
            cwd=str(tmp_path),
        )
        assert proc.returncode == 0, f"init failed: {proc.stdout}{proc.stderr}"

        yield tmp_path

        if os.path.exists(tf):
            os.remove(tf)

    def _login(self, workspace):
        proc = subprocess.run(
            [BIN, "login", "--user", "rune"],
            input="rune-secret-42\n",
            capture_output=True, text=True, timeout=30,
            cwd=str(workspace),
        )
        assert proc.returncode == 0

    def _set_project(self, workspace):
        proc = subprocess.run(
            [BIN, "project", "set", PROJECT_ID],
            capture_output=True, text=True, timeout=30,
            cwd=str(workspace),
        )
        assert proc.returncode == 0

    def test_issue_get_by_ref(self, workspace, client):
        """issue get <ref> should resolve and return the issue."""
        self._login(workspace)
        self._set_project(workspace)

        ts = _ts()
        created = client.create_issue(f"ref test issue {ts}")
        iid, ref = created["id"], created["ref"]
        try:
            proc = subprocess.run(
                [BIN, "--json", "issue", "get", str(ref)],
                capture_output=True, text=True, timeout=30,
                cwd=str(workspace),
            )
            assert proc.returncode == 0, f"issue get by ref failed: {proc.stdout}{proc.stderr}"
            data = json.loads(proc.stdout)["payload"]
            assert data["id"] == iid
            assert data["ref"] == ref
        finally:
            client.delete_issue(iid)

    def test_issue_get_by_db_id_backward_compat(self, workspace, client):
        """issue get <db_id> should still work for backward compatibility."""
        self._login(workspace)
        self._set_project(workspace)

        ts = _ts()
        created = client.create_issue(f"db id test issue {ts}")
        iid, ref = created["id"], created["ref"]
        try:
            proc = subprocess.run(
                [BIN, "--json", "issue", "get", str(iid)],
                capture_output=True, text=True, timeout=30,
                cwd=str(workspace),
            )
            assert proc.returncode == 0, f"issue get by db id failed: {proc.stdout}{proc.stderr}"
            data = json.loads(proc.stdout)["payload"]
            assert data["id"] == iid
            assert data["ref"] == ref
        finally:
            client.delete_issue(iid)

    def test_task_get_by_ref(self, workspace, client):
        """task get <ref> should resolve and return the task."""
        self._login(workspace)
        self._set_project(workspace)

        ts = _ts()
        created = client.create_task(f"ref test task {ts}")
        tid, ref = created["id"], created["ref"]
        try:
            proc = subprocess.run(
                [BIN, "--json", "task", "get", str(ref)],
                capture_output=True, text=True, timeout=30,
                cwd=str(workspace),
            )
            assert proc.returncode == 0, f"task get by ref failed: {proc.stdout}{proc.stderr}"
            data = json.loads(proc.stdout)["payload"]
            assert data["id"] == tid
            assert data["ref"] == ref
        finally:
            client.delete_task(tid)


class TestSubcommandCRUD:
    """Test CRUD operations via subcommand CLI mode."""

    BASE = "http://127.0.0.1:8000/api/v1"

    @staticmethod
    def _token_file():
        home = os.path.expanduser("~")
        return os.path.join(home, ".local", "share", "taiga-cli", "tokens",
                            "http___127.0.0.1_8000_api_v1.json")

    @pytest.fixture
    def workspace(self, tmp_path):
        tf = self._token_file()
        if os.path.exists(tf):
            os.remove(tf)

        proc = subprocess.run(
            [BIN, "init", self.BASE],
            capture_output=True, text=True, timeout=30,
            cwd=str(tmp_path),
        )
        assert proc.returncode == 0, f"init failed: {proc.stdout}{proc.stderr}"

        yield tmp_path

        if os.path.exists(tf):
            os.remove(tf)

    def _login(self, workspace):
        proc = subprocess.run(
            [BIN, "login", "--user", "rune"],
            input="rune-secret-42\n",
            capture_output=True, text=True, timeout=30,
            cwd=str(workspace),
        )
        assert proc.returncode == 0

    def _set_project(self, workspace):
        proc = subprocess.run(
            [BIN, "project", "set", PROJECT_ID],
            capture_output=True, text=True, timeout=30,
            cwd=str(workspace),
        )
        assert proc.returncode == 0

    # --- Task CRUD ---

    def test_task_update(self, workspace, client):
        """task update <ref> --subject S should update the task."""
        self._login(workspace)
        self._set_project(workspace)

        ts = _ts()
        created = client.create_task(f"update test task {ts}")
        tid, ref = created["id"], created["ref"]
        try:
            proc = subprocess.run(
                [BIN, "--json", "task", "update", str(ref), "--subject", f"updated task {ts}"],
                capture_output=True, text=True, timeout=30,
                cwd=str(workspace),
            )
            assert proc.returncode == 0, f"task update failed: {proc.stdout}{proc.stderr}"
            data = json.loads(proc.stdout)["payload"]
            assert data["subject"] == f"updated task {ts}"
        finally:
            client.delete_task(tid)

    def test_task_delete(self, workspace, client):
        """task delete <ref> --force should delete the task."""
        self._login(workspace)
        self._set_project(workspace)

        ts = _ts()
        created = client.create_task(f"delete test task {ts}")
        tid, ref = created["id"], created["ref"]

        proc = subprocess.run(
            [BIN, "task", "delete", str(ref)],
            input="yes\n",
            capture_output=True, text=True, timeout=30,
            cwd=str(workspace),
        )
        assert proc.returncode == 0, f"task delete failed: {proc.stdout}{proc.stderr}"
        assert "deleted" in proc.stdout

        # Verify it's gone
        err = client._err("get-task", {"id": tid, "maybeNat64ArgsTag": ""})
        assert "err" in err

    # --- Epic CRUD ---

    def test_epic_create(self, workspace):
        """epic create <subject> should create an epic."""
        self._login(workspace)
        self._set_project(workspace)

        ts = _ts()
        proc = subprocess.run(
            [BIN, "--json", "epic", "create", f"subcmd epic {ts}", "--description", "test desc"],
            capture_output=True, text=True, timeout=30,
            cwd=str(workspace),
        )
        assert proc.returncode == 0, f"epic create failed: {proc.stdout}{proc.stderr}"
        data = json.loads(proc.stdout)["payload"]
        assert data["subject"] == f"subcmd epic {ts}"
        assert data["description"] == "test desc"

    def test_epic_update(self, workspace, client):
        """epic update <ref> --subject S should update the epic."""
        self._login(workspace)
        self._set_project(workspace)

        ts = _ts()
        created = client.create_epic(f"update epic {ts}")
        eid, ref = created["id"], created["ref"]
        try:
            proc = subprocess.run(
                [BIN, "--json", "epic", "update", str(ref), "--subject", f"updated epic {ts}"],
                capture_output=True, text=True, timeout=30,
                cwd=str(workspace),
            )
            assert proc.returncode == 0, f"epic update failed: {proc.stdout}{proc.stderr}"
            data = json.loads(proc.stdout)["payload"]
            assert data["subject"] == f"updated epic {ts}"
        finally:
            client.delete_epic(eid)

    def test_epic_delete(self, workspace, client):
        """epic delete <ref> should delete the epic."""
        self._login(workspace)
        self._set_project(workspace)

        ts = _ts()
        created = client.create_epic(f"delete epic {ts}")
        eid, ref = created["id"], created["ref"]

        proc = subprocess.run(
            [BIN, "epic", "delete", str(ref)],
            input="yes\n",
            capture_output=True, text=True, timeout=30,
            cwd=str(workspace),
        )
        assert proc.returncode == 0, f"epic delete failed: {proc.stdout}{proc.stderr}"
        assert "deleted" in proc.stdout

        err = client._err("get-epic", {"id": eid, "maybeNat64ArgsTag": ""})
        assert "err" in err

    # --- Story CRUD ---

    def test_story_create(self, workspace):
        """story create <subject> should create a story."""
        self._login(workspace)
        self._set_project(workspace)

        ts = _ts()
        proc = subprocess.run(
            [BIN, "--json", "story", "create", f"subcmd story {ts}", "--description", "test desc"],
            capture_output=True, text=True, timeout=30,
            cwd=str(workspace),
        )
        assert proc.returncode == 0, f"story create failed: {proc.stdout}{proc.stderr}"
        data = json.loads(proc.stdout)["payload"]
        assert data["subject"] == f"subcmd story {ts}"

    def test_story_update(self, workspace, client):
        """story update <ref> --subject S should update the story."""
        self._login(workspace)
        self._set_project(workspace)

        ts = _ts()
        created = client.create_story(f"update story {ts}")
        sid, ref = created["id"], created["ref"]
        try:
            proc = subprocess.run(
                [BIN, "--json", "story", "update", str(ref), "--subject", f"updated story {ts}"],
                capture_output=True, text=True, timeout=30,
                cwd=str(workspace),
            )
            assert proc.returncode == 0, f"story update failed: {proc.stdout}{proc.stderr}"
            data = json.loads(proc.stdout)["payload"]
            assert data["subject"] == f"updated story {ts}"
        finally:
            client.delete_story(sid)

    def test_story_delete(self, workspace, client):
        """story delete <ref> should delete the story."""
        self._login(workspace)
        self._set_project(workspace)

        ts = _ts()
        created = client.create_story(f"delete story {ts}")
        sid, ref = created["id"], created["ref"]

        proc = subprocess.run(
            [BIN, "story", "delete", str(ref)],
            input="yes\n",
            capture_output=True, text=True, timeout=30,
            cwd=str(workspace),
        )
        assert proc.returncode == 0, f"story delete failed: {proc.stdout}{proc.stderr}"
        assert "deleted" in proc.stdout

        err = client._err("get-story", {"id": sid, "maybeNat64ArgsTag": ""})
        assert "err" in err

    # --- Issue CRUD ---

    def test_issue_create(self, workspace):
        """issue create <subject> should create an issue."""
        self._login(workspace)
        self._set_project(workspace)

        ts = _ts()
        proc = subprocess.run(
            [BIN, "--json", "issue", "create", f"subcmd issue {ts}", "--description", "test desc"],
            capture_output=True, text=True, timeout=30,
            cwd=str(workspace),
        )
        assert proc.returncode == 0, f"issue create failed: {proc.stdout}{proc.stderr}"
        data = json.loads(proc.stdout)["payload"]
        assert data["subject"] == f"subcmd issue {ts}"

    def test_issue_update(self, workspace, client):
        """issue update <ref> --subject S should update the issue."""
        self._login(workspace)
        self._set_project(workspace)

        ts = _ts()
        created = client.create_issue(f"update issue {ts}")
        iid, ref = created["id"], created["ref"]
        try:
            proc = subprocess.run(
                [BIN, "--json", "issue", "update", str(ref), "--subject", f"updated issue {ts}"],
                capture_output=True, text=True, timeout=30,
                cwd=str(workspace),
            )
            assert proc.returncode == 0, f"issue update failed: {proc.stdout}{proc.stderr}"
            data = json.loads(proc.stdout)["payload"]
            assert data["subject"] == f"updated issue {ts}"
        finally:
            client.delete_issue(iid)

    def test_issue_delete(self, workspace, client):
        """issue delete <ref> should delete the issue."""
        self._login(workspace)
        self._set_project(workspace)

        ts = _ts()
        created = client.create_issue(f"delete issue {ts}")
        iid, ref = created["id"], created["ref"]

        proc = subprocess.run(
            [BIN, "issue", "delete", str(ref)],
            input="yes\n",
            capture_output=True, text=True, timeout=30,
            cwd=str(workspace),
        )
        assert proc.returncode == 0, f"issue delete failed: {proc.stdout}{proc.stderr}"
        assert "deleted" in proc.stdout

        err = client._err("get-issue", {"id": iid, "maybeNat64ArgsTag": ""})
        assert "err" in err


class TestCommentsSubcommand:
    """Test comment operations via subcommand CLI."""

    BASE = "http://127.0.0.1:8000/api/v1"

    @staticmethod
    def _token_file():
        home = os.path.expanduser("~")
        return os.path.join(home, ".local", "share", "taiga-cli", "tokens",
                            "http___127.0.0.1_8000_api_v1.json")

    @pytest.fixture
    def workspace(self, tmp_path):
        tf = self._token_file()
        if os.path.exists(tf):
            os.remove(tf)

        proc = subprocess.run(
            [BIN, "init", self.BASE],
            capture_output=True, text=True, timeout=30,
            cwd=str(tmp_path),
        )
        assert proc.returncode == 0, f"init failed: {proc.stdout}{proc.stderr}"

        yield tmp_path

        if os.path.exists(tf):
            os.remove(tf)

    def _login(self, workspace):
        proc = subprocess.run(
            [BIN, "login", "--user", "rune"],
            input="rune-secret-42\n",
            capture_output=True, text=True, timeout=30,
            cwd=str(workspace),
        )
        assert proc.returncode == 0

    def _set_project(self, workspace):
        proc = subprocess.run(
            [BIN, "project", "set", PROJECT_ID],
            capture_output=True, text=True, timeout=30,
            cwd=str(workspace),
        )
        assert proc.returncode == 0

    def test_comment_add_and_list_task(self, workspace, client):
        """comment add and list on a task."""
        self._login(workspace)
        self._set_project(workspace)

        ts = _ts()
        created = client.create_task(f"comment test task {ts}")
        tid, ref = created["id"], created["ref"]
        try:
            # Add comment
            proc = subprocess.run(
                [BIN, "comment", "add", "task", str(ref), f"test comment {ts}"],
                capture_output=True, text=True, timeout=30,
                cwd=str(workspace),
            )
            assert proc.returncode == 0, f"comment add failed: {proc.stdout}{proc.stderr}"
            assert "[OK]" in proc.stdout

            # List comments
            proc = subprocess.run(
                [BIN, "--json", "comment", "list", "task", str(ref)],
                capture_output=True, text=True, timeout=30,
                cwd=str(workspace),
            )
            assert proc.returncode == 0, f"comment list failed: {proc.stdout}{proc.stderr}"
            data = json.loads(proc.stdout)["payload"]
            assert isinstance(data, list)
        finally:
            client.delete_task(tid)

    def test_comment_add_issue(self, workspace, client):
        """comment add on an issue."""
        self._login(workspace)
        self._set_project(workspace)

        ts = _ts()
        created = client.create_issue(f"comment test issue {ts}")
        iid, ref = created["id"], created["ref"]
        try:
            proc = subprocess.run(
                [BIN, "comment", "add", "issue", str(ref), f"issue comment {ts}"],
                capture_output=True, text=True, timeout=30,
                cwd=str(workspace),
            )
            assert proc.returncode == 0, f"comment add failed: {proc.stdout}{proc.stderr}"
            assert "[OK]" in proc.stdout
        finally:
            client.delete_issue(iid)


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


class TestOutputFormat:
    """Verify text vs JSON output formatting in subcommand mode."""

    BASE = "http://127.0.0.1:8000/api/v1"

    @staticmethod
    def _token_file():
        home = os.path.expanduser("~")
        return os.path.join(home, ".local", "share", "taiga-cli", "tokens",
                            "http___127.0.0.1_8000_api_v1.json")

    @pytest.fixture
    def workspace(self, tmp_path):
        tf = self._token_file()
        if os.path.exists(tf):
            os.remove(tf)

        proc = subprocess.run(
            [BIN, "init", self.BASE],
            capture_output=True, text=True, timeout=30,
            cwd=str(tmp_path),
        )
        assert proc.returncode == 0, f"init failed: {proc.stdout}{proc.stderr}"

        yield tmp_path

        if os.path.exists(tf):
            os.remove(tf)

    def _login(self, workspace):
        proc = subprocess.run(
            [BIN, "login", "--user", "rune"],
            input="rune-secret-42\n",
            capture_output=True, text=True, timeout=30,
            cwd=str(workspace),
        )
        assert proc.returncode == 0

    def _set_project(self, workspace):
        proc = subprocess.run(
            [BIN, "project", "set", PROJECT_ID],
            capture_output=True, text=True, timeout=30,
            cwd=str(workspace),
        )
        assert proc.returncode == 0

    def test_text_mode_no_json_payload(self, workspace):
        """Text mode should print only a status line, no JSON."""
        self._login(workspace)
        self._set_project(workspace)

        proc = subprocess.run(
            [BIN, "task", "list"],
            capture_output=True, text=True, timeout=30,
            cwd=str(workspace),
        )
        assert proc.returncode == 0
        assert "[OK]" in proc.stdout
        # Should NOT contain JSON braces
        assert "{" not in proc.stdout
        assert "}" not in proc.stdout

    def test_json_mode_pure_json(self, workspace):
        """JSON mode should print ONLY a valid JSON object."""
        self._login(workspace)
        self._set_project(workspace)

        proc = subprocess.run(
            [BIN, "--json", "task", "list"],
            capture_output=True, text=True, timeout=30,
            cwd=str(workspace),
        )
        assert proc.returncode == 0
        # Should be valid JSON (no [OK] prefix)
        assert "[OK]" not in proc.stdout
        data = json.loads(proc.stdout)
        assert "status" in data
        assert "message" in data
        assert "payload" in data
        assert isinstance(data["payload"], list)

    def test_json_mode_pipeable_to_jq(self, workspace):
        """JSON mode output must be pipeable to jq."""
        self._login(workspace)
        self._set_project(workspace)

        proc = subprocess.run(
            [BIN, "--json", "project", "get"],
            capture_output=True, text=True, timeout=30,
            cwd=str(workspace),
        )
        assert proc.returncode == 0
        data = json.loads(proc.stdout)
        # jq '.payload.id' equivalent in Python
        assert "payload" in data
        assert data["payload"]["id"] == int(PROJECT_ID)

    def test_error_text_mode_no_json(self, workspace):
        """Error in text mode should show only text, no JSON."""
        proc = subprocess.run(
            [BIN, "task", "get", "99999"],
            capture_output=True, text=True, timeout=30,
            cwd=str(workspace),
        )
        assert proc.returncode != 0 or "[ERR]" in proc.stdout
        if "[ERR]" in proc.stdout:
            assert "{" not in proc.stdout

    def test_error_json_mode_valid_json(self, workspace):
        """Error in JSON mode should still be valid JSON."""
        proc = subprocess.run(
            [BIN, "--json", "task", "get", "99999"],
            capture_output=True, text=True, timeout=30,
            cwd=str(workspace),
        )
        # Exit code may be non-zero, but stdout must be valid JSON
        data = json.loads(proc.stdout)
        assert "status" in data
        assert data["status"] != 0
