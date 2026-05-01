# Codebase Analysis Report: idris2-taiga-cli

## Executive Summary

**Last updated:** 2026-05-01 (post all refactoring rounds)

All critical and high-priority items from the initial analysis are resolved. The codebase has undergone four rounds of fixes:
1. HTTP response abstraction + bug fixes (commit 39790cc)
2. Missing doc comments added (commit f1e97ab)
3. URL encoding for query strings (commit f7c5211)
4. ToJSON migration + `showId` helper + dead code removal (commits 4afd00f, 02b3859)

The only remaining items are low-priority cosmetic issues: line-length violations and one module not using `buildQueryString`.

---

## 1. What Was Fixed (Verified)

| Fix | File | Evidence |
|---|---|---|
| `expectJson` / `expectOk` / `expectRaw` helpers | `Taiga/Env.idr` | Lines 111-151 |
| `map` instead of `case` on `Maybe` | All `Taiga/*.idr` | `map (\p => ("page", show p)) page` pattern |
| `readNat64` / `readNat32` validation | `CLI/Parse.idr` | Lines 37-53, checks `cast {to=Integer}` |
| `entityPlural` fix | `Taiga/History.idr` | Lines 51-53, handles `userstory` → `userstories` |
| `urlEncode` in `buildQueryString` | `Taiga/Env.idr` | Lines 17-45 |
| `Search.idr` uses `buildQueryString` | `Taiga/Search.idr` | Lines 22, 35 |
| Eta-reduced dead helpers | `Command.idr` | `mkNat64Id = MkNat64Id`, `toMaybeNat64Id = map MkNat64Id` |
| `Model/Common.idr` derives `Eq`/`Ord` | `Model/Common.idr` | Lines 36-39 |
| `Main.idr` auto-implicit syntax | `Main.idr` | `{auto _ : HasIO io}` throughout |
| `runCurlCmd` removed | `Taiga/Api.idr` | Only `runCurlCmdIO` remains |
| **ToJSON migration complete** | All `Taiga/*.idr` | commit 4afd00f, all builders replaced with records + custom ToJSON |
| `resolveBaseUrl` identity removed | `Main.idr` | commit 02b3859, uses `res.base_url` directly |
| `showId` helper added | `Taiga/Env.idr` | commit 02b3859, used across all endpoint modules |
| `liftParser`/`thenDiscard` removed | `CLI/Parse.idr` | commit 39790cc |
| Missing doc comments | All modules | commit f1e97ab, 26 records + types documented |
| URL encoding in query strings | `Taiga/Env.idr`, `Taiga/Search.idr` | commit f7c5211 |

---

## 2. What Remains Unfixed

### 2.1 Line Length Violations (Low Impact, Inherent)

~50 lines exceed 80 chars. The vast majority are data constructor signatures in:

| File | Lines > 80 | Examples |
|---|---|---|
| `Command.idr` | ~20 | `CmdCreateTask`, `CmdCreateIssue`, etc. — many-param constructors + mk* calls |
| `CLI/Args.idr` | ~8 | Mirror of Command constructors (`ArgCreateTask`, etc.) |

**Decision:** Low priority. The long constructor lines are inherent to the API surface. Splitting them would require multi-line constructor definitions which may hurt readability more than the overflow.

### 2.2 Manual `Show` Instances in `Model/Common.idr` (Stylistic)

`Show` for `Nat64Id`, `Slug`, `Version`, `DateTime` are hand-written to produce `"Nat64Id 42"` instead of `"MkNat64Id 42"`. This is an intentional stylistic choice, not a bug. `Eq` and `Ord` are already derived.

### 2.3 ~~Dead Code: `maybeParam`~~ — Fixed (commit e7068a9)

Removed unused helper from `Taiga/Env.idr`.

### 2.4 ~~Inconsistent Indentation in `parameters` Blocks~~ — Fixed (commit e7068a9)

Fixed 3-space indentation to 2-space in `Task.idr`, `UserStory.idr`, and `Project.idr`.

---

## 3. Functional Opportunities

### 3.1 ~~buildUpdate\*Body Generalization~~ — Resolved by ToJSON Migration

No longer applicable. Each endpoint has its own typed record with custom `ToJSON`.

### 3.2 ~~`showId` Helper~~ — Implemented (commit 02b3859)

Added to `Taiga/Env.idr` and used across all endpoint modules.

---

## 4. Summary Table

| Category | Issue | Status | Severity |
|---|---|---|---|
| Anti-pattern | Manual JSON string building | **Fixed** (4afd00f) | — |
| Duplication | `buildUpdate*Body` pattern | **Fixed** (ToJSON migration) | — |
| Duplication | `buildCreate*Body` pattern | **Fixed** (ToJSON migration) | — |
| Verbosity | `liftParser`, `thenDiscard` | **Fixed** (39790cc) | — |
| Verbosity | `resolveBaseUrl` identity | **Fixed** (02b3859) | — |
| Consistency | `User.idr` inline query strings | **Fixed** | Low |
| Style | Line >80 chars (constructors) | **Still present** (inherent) | Low |
| Style | Misaligned `case` RHS in Parser | **Fixed** | — |
| Style | `parameters` block indentation (3 vs 2 spaces) | **Fixed** (e7068a9) | — |
| Dead code | `maybeParam` unused helper | **Fixed** (e7068a9) | — |
| Refactoring | `expectJson`/`expectOk` | **Fixed** | — |
| Refactoring | `map` instead of `case` on `Maybe` | **Fixed** | — |
| Refactoring | `showId` helper | **Fixed** (02b3859) | — |
| Refactoring | URL encoding query strings | **Fixed** (f7c5211) | — |
| Refactoring | Doc comments added | **Fixed** (f1e97ab) | — |
| Bug | `readNat64` silent failure | **Fixed** | — |
| Bug | `addComment` pluralization | **Fixed** | — |
| Bug | Missing URL encoding | **Fixed** | — |
| Style | Auto-implicit syntax | **Fixed** | — |
| Style | Derived `Eq`/`Ord` | **Fixed** | — |
| Dead code | `runCurlCmd` alias | **Fixed** | — |
| Dead code | Eta-expanded wrappers | **Fixed** | — |
