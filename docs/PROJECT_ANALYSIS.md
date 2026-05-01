# Comprehensive Project Analysis: idris2-taiga-cli

**Date:** 2026-05-01
**Lines of Code:** ~3,200 (Idris2)
**Test Count:** 28 (Python pytest)

---

## Executive Summary

A functional, well-structured Idris2 CLI for the Taiga API. Strong type safety, good separation of concerns, and effective use of Idris2 features. Several architectural and code-quality issues remain, primarily around CLI completeness, error handling depth, and functional purity.

---

## Architecture & Design

### What's Good

**Clear module separation.** The project follows a sensible layered architecture:
- `Protocol/` — JSON envelope parsing
- `Model/` — Data types with derived JSON instances  
- `Taiga/` — API endpoint wrappers
- `CLI/` — Human-facing argument parsing
- `Command.idr` — Central dispatch and bridge layer

**Smart use of `parameters` for dependency injection.** `ApiEnv` is threaded via auto-implicit parameters (`{auto env : ApiEnv}`), eliminating repetitive `base`/`token` arguments in every function signature. This is idiomatic Idris2 and much cleaner than a `ReaderT` stack.

**Two-mode design.** The dual agent-mode (stdin JSON) / CLI-mode (flags) architecture is pragmatic and well-executed in `Main.idr`.

### What's Bad

**Massive `Command.idr` (644 lines).** This file violates the Single Responsibility Principle. It contains:
- Argument record definitions (~40 records)
- Command GADT definition (~60 constructors)
- Parsing functions (`parseCommand`, 50+ clauses)
- Dispatch functions (`dispatchCommand`, `dispatchWithEnv'`)
- Helper wrappers (`wrapResult`, `dispatchLogin'`, etc.)

**Bloated Command constructors.** Constructors like `CmdCreateTask` take 7 positional arguments. This hurts readability and makes pattern matching in `dispatchWithEnv'` a wide, error-prone wall of text. Record constructors or a builder pattern would help.

**CLI is severely incomplete.** `CLI/Parse.idr` only implements parsing for:
- `--help`, `--stdin`, `--login`, `--me`
- `--list-projects`, `--watch-task`
- `--change-task-status`, `--task-comment`
- `--list-comments`, `--base`

That's ~10 flags out of ~40+ commands. The rest all hit `failParse "unimplemented flag"`.

### Can Be Better

- **Split `Command.idr`** into `Command/Types.idr`, `Command/Parse.idr`, `Command/Dispatch.idr`
- **Use record syntax for command constructors** or group related args into records
- **Complete the CLI parser** or remove it if agent-mode is the only real use case

---

## Code Quality & Style

### What's Good

**Follows STYLE.md closely.** 2-space indent, 80-char limit respected in most files, `let ... in` preferred over `do ... let`, `where` blocks used appropriately.

**Documented exports.** Most exported functions have doc comments (`||| ...`).

**Consistent naming.** `camelCase` for values, `PascalCase` for types, `kebab-case` for command strings.

### What's Bad

**Long lines in `Command.idr` GADT.** Lines 315-320 exceed 80 chars with 7-arg constructors. The style guide is violated in the most important file.

**Inconsistent pattern matching style.** In `dispatchWithEnv'`, some lines align arrows, others don't:
```idris
CmdGetProject (Just id) _                          => ...
CmdGetProject _ (Just slug)                        => ...
CmdGetProject Nothing Nothing                      => ...
```
The alignment is ragged and hard to scan.

**Dead code in `CLI/Help.idr`.** `usageSynopsis` and `commandHelp` are exported but never used. `knownCommands` is incomplete (only lists 10 commands vs 40+ available).

### Can Be Better

- Auto-format with a tool or enforce line limits in CI
- Use record patterns in `dispatchWithEnv'` to avoid ultra-wide lines:
  ```idris
  CmdGetProject (Just id) _ => dispatchWithEnvHelper (getProjectById @{env} id) encode
  ```

---

## Functional Programming Practices

### What's Good

**Uses `map`, `catMaybes`, `concat` instead of explicit recursion.** The codebase generally avoids manual loops. Query string building in `Taiga/Env.idr` and parameter construction across API modules is functional.

**Derives JSON instances via elaboration reflection.** `%runElab derive "Foo" [Show,ToJSON,FromJSON]` eliminates hundreds of lines of boilerplate.

**Custom JSON instances for wrapper types.** `Nat64Id`, `Slug`, `Version`, `DateTime` serialize as bare values (int/string) rather than wrapped objects — correct for the Taiga API.

### What's Bad

**Manual JSON body construction still present in `Taiga/Auth.idr`.** Uses manual `object [jpair ...]` instead of derived `ToJSON`. While explicit and small, it's inconsistent with the rest of the codebase.

**String concatenation for URLs in `Taiga/Api.idr` (curl commands).** `buildCurlGet` builds shell command strings via `++`. This is inherently imperative/unsafe (shell injection risk, no escaping).

**No use of `traverse` or `sequence` for list-of-Either patterns.** When decoding JSON arrays, there's no evidence of using `traverse` over decoded elements.

### Can Be Better

- Use `traverse` / `sequence` when processing lists of `Either`
- Consider using an effects library for HTTP instead of shelling to curl (though this is a pragmatic choice)
- The `omitNothing` helper is excellent — more polymorphic utilities like this would be good

---

## API & HTTP Layer

### What's Good

**Typed HTTP methods.** `httpGet`, `httpPost`, `httpPut`, `httpPatch`, `httpDelete` with explicit signatures.

**Status code checking via `expectJson`/`expectOk`/`expectRaw`.** Centralized, consistent error handling for HTTP status codes.

### What's Bad

**Shell injection vulnerability.** `Taiga/Api.idr` builds curl commands by concatenating strings without shell escaping:
```idris
buildCurlGet url auth =
  "curl -s -w \"\\n%{http_code}\" " ++ authFlag ++ " \"" ++ url ++ "\""
```
If `url` or `token` contains a quote, the command breaks or worse. The `urlEncode` in `Taiga/Env.idr` only encodes query params, not the full URL or token.

**No timeout configuration.** `runCurlCmdIO` uses `popen` with no timeout. A hung curl process blocks forever.

**No retry logic.** Transient network failures fail immediately.

**Curl stderr merged blindly.** `cmd' ++ " 2>&1"` means HTTP error bodies and curl errors are indistinguishable.

**Missing `delete-milestone` command.** The API module has no delete endpoint for milestones, yet other entities (epic, story, task, issue, wiki) all have deletes. This is an API gap.

### Can Be Better

- Shell-escape all interpolated values, or better: use `exec` with argument array instead of string shell command
- Add configurable timeouts
- Distinguish curl errors from HTTP error responses
- Add `deleteMilestone` to complete CRUD parity

---

## JSON Handling

### What's Good

**Elaboration reflection for derivation.** Reduces boilerplate massively.

**Tag fields for single-field records.** The `"fooArgsTag": ""` workaround for `idris2-json` unwrapping is applied consistently and documented.

**Polymorphic `omitNothing`.** Correctly uses `Encoder v =>` constraint to work inside `toJSON` implementations.

### What's Bad

**Inconsistent `Maybe` field handling.** Some request bodies use `omitNothing` (good), but `CreateMilestoneBody` doesn't — it always sends all four fields even if empty.

**No validation on JSON decode.** `decodeEither` failures produce generic `Error in $: ...` messages that bubble up raw to the user. The parser error is exposed unwrapped.

### Can Be Better

- Add a validation layer between JSON decode and command execution
- Custom error messages for decode failures per command type

---

## Error Handling

### What's Good

**Structured error responses.** `ErrorResponse` with `ok`, `err` (machine code), `msg` (human text) is a solid design.

**Early validation.** `parseCommand` returns `Either String Command`. `dispatchCommand` validates auth/token presence before hitting the API.

### What's Bad

**Error codes are strings, not a sum type.** `"bad_request"`, `"unauthorized"`, `"api_error"`, etc. are magic strings scattered across the codebase. A sum type would enable exhaustive pattern matching in tests and clients.

**Generic `"api_error"` for all HTTP failures.** `wrapResult` maps every `Left` from the API layer to the same error code. A 404 vs 500 vs network timeout all look identical to the caller.

**Silent failures in `runCurlCmdIO`.** `popen` failure, `fRead` failure, and `pclose` failure all return `MkHttpResponse (MkStatusCode 1) ""` — no diagnostic message at all.

**No logging.** There's no way to debug what HTTP requests are being made. A `--verbose` flag or debug logging would be invaluable.

### Can Be Better

```idris
data ErrorCode = ParseError | BadRequest | Unauthorized | NotFound | ServerError | NetworkError
```

- Add structured error types
- Propagate curl/HTTP status codes through the error chain
- Add optional debug logging of requests/responses

---

## Testing

### What's Good

**Comprehensive integration test coverage.** 28 tests covering CRUD for all major entities, auth, search, comments, error cases.

**Session-scoped fixture.** `client` logs in once, reducing test runtime.

**Cleanup in `finally` blocks.** CRUD tests clean up created entities.

### What's Bad

**No unit tests for Idris code.** All tests are Python pytest integration tests. The parser (`CLI/Parse.idr`), JSON instances, and utility functions have zero direct test coverage.

**Milestone test leaks data.** `test_create_update_milestone` creates milestones but can't delete them (no CLI command). This accumulates test data.

**Tests depend on a live Taiga instance.** No mock server or recorded fixtures. Tests can't run offline or in CI without infrastructure.

**Weak assertions before recent fixes.** Error tests only checked `"err" in resp` rather than specific error codes.

**No concurrency tests.** OCC (optimistic concurrency control) is only tested for `update-task`. Other mutation commands aren't tested for version conflicts.

### Can Be Better

- Add Idris-level unit tests for parsers, JSON encoding/decoding
- Add `delete-milestone` command and cleanup in tests
- Consider VCR.py or similar for recording/replaying HTTP interactions
- Add OCC conflict tests for all mutable entities

---

## Security

### What's Good

**Token passed via Authorization header.** Correct `Bearer <token>` format.

**Password not stored.** `CredentialAuth` is parsed from the request but the password isn't persisted.

### What's Bad

**Shell injection (mentioned above).** This is the most serious security issue.

**No HTTPS enforcement.** The code happily accepts `http://` URLs.

**Tokens may appear in process listings.** Curl commands with `--header "Authorization: Bearer ..."` are visible in `ps` on multi-user systems.

**No input sanitization on `subject`, `description`, `comment` fields.** These are passed straight into JSON bodies. While JSON encoding prevents shell injection, there's no length validation or XSS filtering.

### Can Be Better

- Use `execve`-style invocation instead of shell string for curl
- Validate URL scheme (warn on http://)
- Consider token passing via environment variable or temp file instead of command line

---

## Build System & Dependencies

### What's Good

**Nix flakes for reproducibility.** 20+ Idris2 libraries pinned to exact git commits.

**Simple `.ipkg` file.** Only declares `depends = json` — Nix handles the rest.

**Helper scripts.** `build` and `run` shell scripts in the dev shell.

### What's Bad

**Many unused dependencies in `flake.nix`.** `idris2-tui-src`, `idris2-async-src`, `idris2-linux-src`, etc. are pinned but never imported by the code. This bloats the lock file and update time.

**No CI configuration.** No `.github/workflows/`, no `nix build` check on push.

**Build warnings not checked.** `build` might succeed with totality warnings or deprecation notices that go unseen.

### Can Be Better

- Prune unused flake inputs
- Add GitHub Actions workflow for `nix build` + `pytest`
- Enable Idris2 totality checking (`%default total`)
- Add a pre-commit hook for style checks

---

## Specific File Issues

### `src/Main.idr`
- Line 101: `[] => putStrLn usage` — when run with no args, prints usage. But line 102 says `_ => runCLI args'`. If you run `./taiga-cli --help`, it works. But `./taiga-cli` alone just prints usage and exits 0. Should probably exit non-zero for "no command given".

### `src/Command.idr`
- Line 641: `env = MkApiEnv baseUrl token.auth_token` — constructs `ApiEnv` but discards `token.refresh`. If the API returns a new token, it's lost.
- The fallback `_ => pure $ Err ... "Unreachable"` on line 625 is a code smell — GADT pattern matching should be exhaustive. This indicates the GADT has grown organically and may have unreachable constructors.

### `src/Taiga/Api.idr`
- `parseHttpResponse` assumes curl output format. Fragile.
- No way to set curl options (timeouts, retries, custom CA certs).

### `src/Taiga/Env.idr`
- `parseBits64 = cast` — `cast` from `String` to `Bits64` in Idris2 will silently return 0 on invalid input. This is dangerous. Should use `readNat64` from `CLI.Parse` or a proper parser.

### `src/CLI/Parse.idr`
- `readNat64` and `readNat32` have the "0" vs "not a number" confusion fixed, but they still don't handle overflow.
- Most flags are unimplemented.

---

## Summary: Prioritized Recommendations

### Critical (Fix Soon)
1. **Shell escaping in curl commands** — security risk
2. **Add `delete-milestone` command** — API parity and test cleanup
3. **Complete CLI parser or remove it** — currently broken for most commands
4. **Fix `parseBits64`** — use safe parsing instead of `cast`

### High Priority
5. **Split `Command.idr` into smaller modules**
6. **Add structured error codes (sum type)**
7. **Prune unused Nix flake inputs**
8. **Add CI/CD pipeline**

### Medium Priority
9. **Add Idris-level unit tests**
10. **Add request/response debug logging**
11. **Add timeout and retry configuration**
12. **Strengthen totality checking**

### Low Priority
13. **Auto-format codebase**
14. **Add HLS-style IDE support configs**
15. **Document the JSON unwrapping quirk in a DESIGN.md**

---

## Grade

| Category | Score | Notes |
|---|---|---|
| Type Safety | A | Strong types, GADTs, auto-implicits |
| Architecture | B+ | Good layers, but `Command.idr` is a god object |
| Functional Style | B+ | Good use of map/filter, but some imperativity in HTTP layer |
| Code Quality | B | STYLE.md followed, but some long lines and dead code |
| Security | C+ | Shell injection risk, tokens in process list |
| Testing | B | Good integration coverage, no unit tests, leaks data |
| CLI Completeness | D | Only ~25% of flags implemented |
| Documentation | B | Good function docs, missing architectural docs |

**Overall: B+** — Solid, functional, well-typed codebase with clear architecture and good test coverage. Main issues are the bloated `Command.idr`, incomplete CLI, shell injection risk, and missing `delete-milestone`. These are all fixable and would bring the project to an A.
