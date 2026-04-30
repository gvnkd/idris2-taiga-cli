# Agent Instructions for idris2-taiga-cli

## Build & Run

- **Enter dev shell:** `nix develop` (flakes enabled; `.envrc` has `use flake`)
- **Build:** `build` (shell script → `idris2 --build taiga-cli.ipkg`)
- **Run:** `run` (shell script → build then `./build/exec/taiga-cli`)
- **No Idris test runner.** Tests are Python pytest in `tests/`.
- **Run tests:** `pytest tests/` — requires a live Taiga instance at `http://127.0.0.1:8000/api/v1`
- **Binary output:** `build/exec/taiga-cli`

## Architecture

- **Entry point:** `src/Main.idr` — agent mode (stdin JSON, default) vs CLI mode (parsed flags)
- **Command dispatch:** `src/Command.idr` — sum type + `parseCommand` / `dispatchCommand`
- **HTTP client:** `src/Taiga/Api.idr` — shells out to `curl` via `popen`, parses status/body
- **Protocol:** `src/Protocol/{Request,Response}.idr` — JSON envelopes
- **Models:** `src/Model/*.idr` — records with `%runElab derive [ToJSON,FromJSON]`
- **Style:** Follow `STYLE.md` (80 chars, 2 spaces, GADT-style data, `let ... in`, `where` blocks)

## Critical Idris2 / JSON Gotchas

1. **`args` field in Request is a `String`, not an object.**
   The agent sends `{"cmd":"...","args":"{\"id\":42}"}` — `args` is a JSON string that gets parsed separately.

2. **Single-field argument records need dummy tag fields** to prevent `idris2-json` from unwrapping them:
   - `StringArgs` → add `"stringArgsTag":""`
   - `MaybeStringArgs` → add `"maybeStringArgsTag":""`
   - `Nat64Args` → add `"nat64ArgsTag":""`
   - `MaybeNat64Args` → add `"maybeNat64ArgsTag":""`
   - `ListProjectsArgs` → add `"listProjectsTag":""`

3. **Custom JSON for wrapped IDs:** `Nat64Id`, `Slug`, `Version`, `DateTime` have hand-written `FromJSON`/`ToJSON` instances in `Model/Common.idr` that serialize as bare ints/strings, not wrapped objects. Do not `derive` these.

4. **Do-block param limit:** Max ~3 explicit params before Idris2 parser fails with `Expected '=>'`. Extract helpers to top-level with ≤3 params. Multiline `let` in do-blocks often fails — use `let ... in do ...` or a top-level helper.

5. **Deriving:** All models use `%language ElabReflection` and `%runElab derive "TypeName" [Show,ToJSON,FromJSON]`.

## Testing

- Tests are in `tests/test_taiga_cli.py` with `tests/conftest.py`
- Binary path is hardcoded: `/srv/taiga-cli/build/exec/taiga-cli`
- Test project: id 12, slug `taiga`
- Default credentials: `rune` / `rune-secret-42`
- `client` fixture is session-scoped and logs in once
- CRUD tests create temp entities and clean up in `finally` blocks
- `change-task-status` and `task-comment` have special OCC behavior (see test comments)

## Dependencies

- Managed entirely via Nix flakes (`flake.nix` + `nix/idris2_packages.nix`)
- `taiga-cli.ipkg` only declares `depends = json` — Nix supplies the rest
- Do not add new deps to `ipkg` without also updating the Nix expression
- Many libraries are pinned to specific git commits in `flake.nix`

## Protocol Reminders

- **Auth header:** `Authorization: Bearer <token>`
- **Taiga API:** No trailing slashes on endpoints (`/projects`, not `/projects/`)
- **OCC:** All mutations require a `version` field
- **Response shape:** `{"ok":true,"data":"..."}` or `{"ok":false,"err":"...","msg":"..."}`
