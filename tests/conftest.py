import json
import subprocess
from datetime import date, timedelta

import pytest

BIN = "/srv/taiga-cli/build/exec/taiga-cli"
BASE = "http://127.0.0.1:8000/api/v1"
PROJECT_ID = "13"


def _run(cmd, args_dict, token=None):
    """Send a command via stdin agent protocol and return parsed Response."""
    req = {
        "cmd": cmd,
        "args": json.dumps(args_dict),
        "auth": {"tag": "TokenAuth", "contents": token} if token else None,
        "base": BASE,
    }
    proc = subprocess.run(
        [BIN, "--stdin"],
        input=json.dumps(req),
        capture_output=True, text=True, timeout=30,
    )
    return json.loads(proc.stdout)


def _assert_ok(resp):
    """Assert response is Ok and return the raw payload string."""
    assert resp["tag"] == "Ok", f"Expected Ok, got Err: {resp}"
    return resp["contents"]["payload"]


@pytest.fixture(scope="session")
def auth_info():
    """Login once per session, return (token, refresh)."""
    creds = {"username": "rune", "password": "rune-secret-42"}
    resp = _run("login", creds)
    payload = json.loads(_assert_ok(resp))
    return payload["auth_token"], payload.get("refresh")


@pytest.fixture(scope="session")
def auth_token(auth_info):
    return auth_info[0]


class TaigaClient:
    """Thin wrapper around taiga-cli agent mode."""

    def __init__(self, token):
        self.token = token

    # --- generic dispatchers --------------------------------------------------
    def _json(self, cmd, args):
        """Call command and return decoded JSON payload."""
        raw = _assert_ok(_run(cmd, args, self.token))
        return json.loads(raw)

    def _raw(self, cmd, args):
        """Call command and return the raw (non-JSON-decoded) payload string."""
        return _assert_ok(_run(cmd, args, self.token))

    def _err(self, cmd, args):
        """Call command and assert response is Err, return error details."""
        resp = _run(cmd, args, self.token)
        assert resp["tag"] == "Err", f"Expected Err, got Ok: {resp}"
        return resp["contents"]

    def refresh(self, token):
        """Refresh the auth token and return new token string."""
        return self._json("refresh", {"refresh": token, "refreshArgsTag": ""})

    # --- auth -----------------------------------------------------------------
    def me(self):
        return self._json("me", {})

    # --- projects -------------------------------------------------------------
    def list_projects(self):
        return self._json("list-projects", {"member": None, "listProjectsTag": ""})

    def get_project_by_id(self, pid):
        return self._json("get-project", {"id": pid, "slug": None})

    # --- epics ----------------------------------------------------------------
    def list_epics(self):
        return self._json("list-epics", {"project": PROJECT_ID, "stringArgsTag": ""})

    def get_epic(self, eid):
        return self._json("get-epic", {"id": eid, "maybeNat64ArgsTag": ""})

    def create_epic(self, subject):
        return self._json("create-epic", {
            "project": PROJECT_ID, "subject": subject,
            "description": None, "status": None,
        })

    def update_epic(self, eid, subject=None, version=1):
        return self._json("update-epic", {
            "id": eid, "subject": subject,
            "description": None, "status": None, "version": version,
        })

    def delete_epic(self, eid):
        """Delete returns raw 'deleted' string — use _raw."""
        return self._raw("delete-epic", {"id": eid, "nat64ArgsTag": ""})

    # --- stories --------------------------------------------------------------
    def list_stories(self):
        return self._json("list-stories", {"project": PROJECT_ID, "stringArgsTag": ""})

    def get_story(self, sid):
        return self._json("get-story", {"id": sid, "maybeNat64ArgsTag": ""})

    def create_story(self, subject):
        return self._json("create-story", {
            "project": PROJECT_ID, "subject": subject,
            "description": None, "milestone": None,
        })

    def update_story(self, sid, subject=None, version=1):
        return self._json("update-story", {
            "id": sid, "subject": subject,
            "description": None, "milestone": None, "version": version,
        })

    def delete_story(self, sid):
        return self._raw("delete-story", {"id": sid, "nat64ArgsTag": ""})

    # --- tasks ----------------------------------------------------------------
    def list_tasks(self):
        return self._json("list-tasks", {"project": None, "maybeStringArgsTag": ""})

    def get_task(self, tid):
        return self._json("get-task", {"id": tid, "maybeNat64ArgsTag": ""})

    def create_task(self, subject):
        return self._json("create-task", {
            "project": PROJECT_ID, "subject": subject,
            "story": None, "description": None,
            "status": None, "milestone": None,
        })

    def update_task(self, tid, subject=None, version=1):
        return self._json("update-task", {
            "id": tid, "subject": subject,
            "description": None, "status": None, "version": version,
        })

    def delete_task(self, tid):
        return self._raw("delete-task", {"id": tid, "nat64ArgsTag": ""})

    def watch_task(self, tid):
        return self._json("watch-task", {"id": tid, "nat64ArgsTag": ""})

    def change_task_status(self, tid, status, version):
        """OCC: version must match the CURRENT version of the entity."""
        return self._json("change-task-status", {
            "id": tid, "status": status, "version": version,
        })

    def task_comment(self, tid, text, version):
        """Returns raw string 'comment added'."""
        return self._raw("task-comment", {
            "id": tid, "text": text, "version": version,
        })

    # --- issues ---------------------------------------------------------------
    def list_issues(self):
        return self._json("list-issues", {"project": PROJECT_ID, "stringArgsTag": ""})

    def get_issue(self, iid):
        return self._json("get-issue", {"id": iid, "maybeNat64ArgsTag": ""})

    def create_issue(self, subject):
        return self._json("create-issue", {
            "project": PROJECT_ID, "subject": subject,
            "description": None, "priority": None,
            "severity": None, "type": None,
        })

    def update_issue(self, iid, subject=None, version=1):
        return self._json("update-issue", {
            "id": iid, "subject": subject,
            "description": None, "type": None, "status": None, "version": version,
        })

    def delete_issue(self, iid):
        return self._raw("delete-issue", {"id": iid, "nat64ArgsTag": ""})

    # --- wiki -----------------------------------------------------------------
    def list_wiki(self):
        return self._json("list-wiki", {"project": PROJECT_ID, "stringArgsTag": ""})

    def get_wiki(self, wid):
        return self._json("get-wiki", {"id": wid, "maybeNat64ArgsTag": ""})

    def create_wiki(self, slug, content):
        return self._json("create-wiki", {
            "project": PROJECT_ID, "slug": slug, "content": content,
        })

    def update_wiki(self, wid, content=None, version=1):
        return self._json("update-wiki", {
            "id": wid, "content": content,
            "slug": None, "version": version,
        })

    def delete_wiki(self, wid):
        return self._raw("delete-wiki", {"id": wid, "nat64ArgsTag": ""})

    # --- milestones -----------------------------------------------------------
    def list_milestones(self):
        return self._json("list-milestones", {"project": PROJECT_ID, "stringArgsTag": ""})

    def create_milestone(self, name):
        today = date.today()
        tomorrow = today + timedelta(days=1)
        return self._json("create-milestone", {
            "project": PROJECT_ID,
            "name": name,
            "estimated_start": today.isoformat(),
            "estimated_finish": tomorrow.isoformat(),
        })

    def update_milestone(self, mid, name=None, version=1):
        return self._json("update-milestone", {
            "id": mid, "name": name,
            "estimated_start": None, "estimated_finish": None,
            "version": version,
        })

    def delete_milestone(self, mid):
        """Delete returns raw 'deleted' string — use _raw."""
        return self._raw("delete-milestone", {"id": mid, "nat64ArgsTag": ""})

    # --- comments -------------------------------------------------------------
    def add_comment(self, entity, eid, text):
        return self._raw("comment", {
            "entity": entity, "id": eid, "text": text,
        })

    def list_comments(self, entity, eid):
        return self._json("list-comments", {"entity": entity, "id": eid})

    # --- search / resolve -----------------------------------------------------
    def search(self, text):
        raw = _assert_ok(_run("search", {
            "project": PROJECT_ID, "text": text,
        }, self.token))
        return json.loads(raw)

    def resolve(self, ref):
        raw = _assert_ok(_run("resolve", {
            "project": "test-project", "ref": ref,
        }, self.token))
        return json.loads(raw.strip())

    # --- users / memberships / roles ------------------------------------------
    def list_users(self):
        return self._json("list-users", {"project": PROJECT_ID, "stringArgsTag": ""})

    def list_memberships(self):
        return self._json("list-memberships", {"project": PROJECT_ID, "stringArgsTag": ""})

    def list_roles(self):
        return self._json("list-roles", {"project": PROJECT_ID, "stringArgsTag": ""})


@pytest.fixture(scope="session")
def client(auth_token):
    """Session-scoped client reused across all tests."""
    return TaigaClient(auth_token)
