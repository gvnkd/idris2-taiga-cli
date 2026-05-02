# Performance Analysis: deps/http for One-Shot CLI Operations

## Executive Summary

The `deps/http` library is architected as a **long-lived, connection-pooled, multi-threaded HTTP client** — optimal for daemons or services making many requests, but it imposes roughly an order of magnitude of overhead for one-shot CLI operations where the process exits after a single request.

---

## Root Cause: Architecture / Use-Case Mismatch

### What curl does (fast path)
```
main thread: socket() → connect() → send() → recv() → close() → exit
```
Single thread, zero synchronization, zero heap structures beyond the socket buffer.

### What deps/http does (slow path)
```
main thread:   new_client() → create PoolManager → create Pool → create Queue
            → request() → start_request() → schedule_request()
            → signal Queue → forkIO worker thread
            → channelGet() [blocks]
            → close() → evict_all() → broadcast Kill → conditionWaitTimeout()

worker thread: recv() Queue [blocks] → socket() → connect() → send() → recv()
            → channelPut() response → loop waiting for next request [dies idle]
```

---

## Bottleneck Breakdown

| Source | Overhead | Why |
|--------|----------|-----|
| **PoolManager + Pool + Queue allocation** | ~tens of µs | `newIORef`, `mk_queue` (mutex + `IORef (Seq _)`) created for every request |
| **Worker thread spawn (`forkIO`)** | **~0.3–1.0 ms** | Idris2 `forkIO` maps to a **pthread creation**. For a single request this is pure dead weight. |
| **Queue/Channel synchronization** | ~hundreds of µs | Two context switches + mutex acquire/release + `Seq` operations: main→queue→worker→channel→main |
| **Worker idle loop** | ~delay until `close()` | After one request the worker sits in `recv queue` forever; `close`/`evict_all` must broadcast `Kill` and `conditionWaitTimeout` to reap it |
| **TCP connect to localhost** | ~0.1 ms | Negligible, but paid on every request because connections cannot be reused across CLI invocations |
| **TLS handshake** | N/A (HTTP only) | Not a factor here (Taiga uses `http://127.0.0.1:8000`), but would be significant for HTTPS |

**The actual HTTP wire time (send + recv) is < 1 ms.** The remaining ~900+ ms is framework overhead.

---

## Critical Code Paths

### 1. Per-request client creation (`Taiga.Api.idr`)
Every HTTP helper (`httpGet`, `httpPost`, etc.) calls `mkClient` → `new_client`, building a fresh `PoolManager` with empty `IORef []`, then immediately `close`s it after one request.

### 2. Unconditional worker spawn (`ConnectionPool.idr:179–194`)
```idris
when {f=IO} second_condition $ do
  _ <- forkIO $ spawn_worker pool.scheduled ...
```
For a fresh client, `local = 0`, `has_idle = False`, so `second_condition` is **always true**. A new pthread is spawned for every single request.

### 3. Async queue/channel plumbing (`Scheduler.idr:64–66`)
```idris
mvar <- makeChannel
schedule_request scheduler protocol $ MkScheduleRequest msg content mvar
Right response <- channelGet mvar
```
The main thread delegates the actual socket I/O to a worker and blocks on a `Channel`. This indirection is necessary for connection reuse in a pool, but useless for one-shot use.

### 4. Cleanup cost (`ConnectionPool.idr:196–205`)
```idris
evict_all manager = do
  ...
  traverse_ (close_pool condition) pools
  wait_for_worker_close mutex condition pools
```
Closing the client broadcasts `Kill` to all workers and waits up to 1-second timeouts for each worker thread to exit.

---

## Recommended Fix: Synchronous Request Path

Add a **direct/synchronous request function** to `Network.HTTP.Client` that bypasses the pool, queues, channels, and threads entirely. This keeps the existing pooled API for concurrent/long-lived users while giving CLI code a zero-overhead path.

### Proposed API

```idris
||| Perform a single-shot HTTP request synchronously in the calling thread.
||| No connection pooling, no worker threads. Socket is opened, used, and closed.
||| Suitable for CLI tools and other one-shot use cases.
export
requestSync :
     {e : _}
  -> (cert_checker : String -> CertificateCheck IO)
  -> Method
  -> URL
  -> List (String, String)
  -> (length : Nat)
  -> (input : Stream (Of Bits8) IO (Either e ()))
  -> IO (Either (HttpError e) (HttpResponse, List Bits8))
```

And a convenience wrapper:

```idris
export
simpleRequest :
     {e : _}
  -> (cert_checker : String -> CertificateCheck IO)
  -> Method
  -> String          -- URL
  -> List (String, String)
  -> Maybe String    -- body
  -> IO (Either (HttpError e) (HttpResponse, List Bits8))
```

### Implementation Strategy

The existing `worker_logic` in `Worker.idr` already contains the correct HTTP protocol implementation:
- Serialize request headers
- Write body stream
- Read response headers (`read_until_empty_line`)
- Parse response (`deserialize_http_response`)
- Read fixed-length or chunked body
- Handle `Connection: keep-alive/close`

**Refactor:** extract the socket I/O logic from `worker_logic` into a pure synchronous function `do_request_sync` that takes a `Handle'` (or raw `Socket`) and returns `(HttpResponse, List Bits8)`.

Then:
- **Pooled path:** `spawn_worker` calls `do_request_sync` inside `worker_loop`.
- **Sync path:** `requestSync` creates a socket, connects, optionally wraps it in TLS (for HTTPS), calls `do_request_sync`, closes the socket, and returns.

This is a minimal refactor (~50 lines of new code, ~30 lines of extraction) and preserves all existing behavior.

### Why Not Other Options?

| Alternative | Drawback |
|-------------|----------|
| Cache `HttpClient` across CLI invocations | Requires IPC (Unix socket, file lock, daemon) — massive complexity |
| Reuse worker thread for multiple requests in one CLI run | Most CLI commands make exactly one request; the benefit is marginal |
| Tune pool params to 1 connection | Still pays `forkIO`, Queue, Channel, and `evict_all` costs |

---

## Expected Performance Impact

With a synchronous path, the one-shot request flow becomes:
```
socket() → connect() → send() → recv() → close()
```
This should reduce per-request latency from **~1 s** to **~1–5 ms** (comparable to curl for localhost HTTP), a **200–1000× speedup**.

---

## Files to Modify

1. **`deps/http/src/Network/HTTP/Pool/Worker.idr`** — extract `do_request_sync` from `worker_logic`
2. **`deps/http/src/Network/HTTP/Client.idr`** — add `requestSync` / `simpleRequest`
3. **`src/Taiga/HttpClient.idr`** — add `httpRequestSync` convenience wrappers
4. **`src/Taiga/Api.idr`** — switch `httpGet`/`httpPost`/etc. to use sync client (or add a config flag)

---

## Quick Verification

If you want to confirm the bottleneck before writing code, add `time` prints around these points in `Taiga.Api.idr`:
1. Before/after `mkClient`
2. Before/after `httpGet`/`httpPost`
3. Before/after `close client`

You will see the majority of the time is spent in `mkClient` + `close`, not in the actual HTTP call.
