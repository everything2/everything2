# Toward a 100% API-driven E2 — architecture & the I/O testing story

**Status:** design / direction (2026-06-09). Written to think through the end state Jay
described: *"start moving HTTP responses out of Controllers and finalize the move to a 100%
API-driven site … to help get more granular testing around inputs and outputs."* This is the
incremental north star, **not** a single push. The CGI removal + `Everything::Response`
(2026-06-08/09) are step 0 of it.

---

## The principle that unlocks everything

**Controllers become pure functions: `(request data) → (response data)`. HTTP lives *only* in
the response/routing layer.**

Today controllers (`Everything::Controller::*`, `Everything::Page::*`) do a mix — they produce
data *and*, in places, do HTTP work (print headers, emit redirects, assemble the `e2` blob).
That mixing is exactly what makes them hard to test: you can't assert a controller's output
without standing up the request/response/render machinery.

Strip the HTTP out and a controller is a function you can call with a fixture and assert on:

```
display($REQUEST, $node)  ->  [ $status, \%data, \%signals ]      # no print, no header, no redirect
```

`%signals` carries the *intent* the response layer acts on — `{ redirect => $url }`,
`{ cookie => {...} }`, `{ status => 303 }` — rather than the controller reaching out and doing
it. The router + `Everything::Response` translate `[status, data, signals]` into an actual HTTP
response (status line, headers, Set-Cookie, body, compression, content-negotiation).

This is already *most* of the API shape — `Everything::API::*` controllers return
`[status, body, headers]` today. The work is (a) finishing that contract for the page path and
(b) making the response layer the single place HTTP happens.

---

## Current state → end state

| Layer | Today | End state |
|---|---|---|
| Request parse | ✅ Plack::Request (`PlackQuery`) — CGI gone | unchanged |
| Response format | ✅ `Everything::Response` (Plack::Response/Cookie::Baker) — CGI gone | unchanged |
| Emission | STDOUT capture in app.psgi parses printed headers | controllers **return** a response; app.psgi `finalize`s it (no capture) |
| API controllers | return `[status, body, headers]`; router prints | return `[status, body, signals]`; router builds `Everything::Response` |
| Page controllers | assemble `e2` blob + render HTML shell server-side; print | return content data; shell + data served via the API |
| Page data (`e2` blob) | `buildNodeInfoStructure` (947-line god-method) prints into the shell | `PageState` → `/api/pagestate` (chrome) + `/api/nodes/:id` (content) |
| Routing | server decides page vs API; renders HTML per page | React owns routing; server serves a static shell + JSON |

The end state: **the server serves a thin, cacheable React shell plus JSON from the same API the
client already calls.** No bespoke per-page HTML render. "Page load" and "client navigation"
become the same code path (fetch pagestate + node content).

---

## The incremental path (each step independently shippable + testable)

0. **CGI out of request & response layers.** ✅ done. `PlackQuery` (request) +
   `Everything::Response` (response). Nothing prints through CGI anymore.

1. **Return-based responses (retire the STDOUT capture).** The API path already returns a value;
   have `Router::output` build an `Everything::Response` and app.psgi `finalize` it directly when a
   handler returns one — **dual-mode**: returned response bypasses the capture (→ immune to the
   #4237 capture-poisoning bug class), printed output still falls back to the capture. The page
   path converts as its `print` sites move into returned content. Capture is deleted last.
   *(This is "moving HTTP out of controllers" — the first real step of Jay's ask.)*

2. **`PageState` extraction (the `e2` blob → an API seam).** Pull `buildNodeInfoStructure` out of
   the `Application.pm` god-module into `Everything::PageState`, split **chrome** (page-independent
   per-user shell: nodelets, identity, messages, system — cacheable) from **content** (per-node).
   Chrome becomes `/api/pagestate`; content is `/api/nodes/:id`. (Design: the deferred
   `plack-request-migration.md` Appendix C.)

3. **Controllers return content, not HTML.** Each page controller's `display` returns its content
   data + signals; the shell mounts with `pagestate + content`. Controllers stop touching HTML.

4. **React-owned routing.** Once chrome/content are separate API resources, the client navigates by
   fetching them — the server serves only the static shell. Page render leaves the server.

5. **Delete the page-render machinery** (the HTML shell assembly, the capture, the
   `buildNodeInfoStructure` delegate).

---

## The I/O testing story (the actual goal)

The reason to do this is **granular, fast tests around inputs and outputs** — which the current
architecture fights. Once the layers are clean, three test tiers fall out naturally:

### 1. Input layer — request parsing (already have the seam)
The request is pure parsing (`PlackQuery` over `Plack::Request`). The **CGI↔Plack parity harness**
(t/123) already pins the decode layer (params, multi-value, UTF-8, cookies, bodies) as a unit.
Add: a fixture-driven corpus of real request shapes → assert the normalized `(params, user,
body, headers)` a controller would see. *Inputs validated once, as a layer.*

### 2. Controller layer — pure data in/out (the net we lack)
With controllers as `(request data) → (response data)`, each is unit-testable: construct a request
fixture (params + user + node), call it, assert the returned **data structure** — no HTTP, no
render, no whole-world DB. This is the controller test net E2 has ~zero of today. A **parametrized
harness** runs every controller's `display` against a representative node and asserts a
well-formed result.

### 3. Output layer — response building + contracts
- **Response building:** given `[status, data, signals]`, assert the finalized PSGI response —
  status, headers, Set-Cookie, body, compression. The `Everything::Response` parity tests (t/126)
  are the seed; this layer owns "did we emit the right HTTP."
- **Contract tests:** once output is pure data, every endpoint's response gets a **schema/shape
  assertion** (a JSON-schema or a structural matcher per endpoint). New endpoints add a contract;
  changes that break a contract fail loudly. *This is the "granular testing around inputs and
  outputs" — inputs pinned at tier 1, outputs pinned at tier 3, the logic isolated at tier 2.*

The shape: **parse (tier 1) → pure controller (tier 2) → response/contract (tier 3)**, each a fast
unit boundary instead of one slow end-to-end blob. e2e stays as the thin integration backstop, not
the only safety net.

---

## How tonight's work fits

- `Everything::Response` is the tier-3 vehicle: it's where `[status, data, signals]` becomes HTTP,
  and where response/contract tests live. It already exposes `finalize` (a real PSGI triple), so
  step 1 (return-based) is a small router change, not a rewrite.
- `PlackQuery` is the tier-1 vehicle: pure request parsing, already parity-pinned.
- The missing middle is tier 2 — which arrives with `PageState` (step 2) giving controllers a clean
  data target, and the controller contract (`[status, data, signals]`) letting them stop printing.

## Open questions to settle before step 1
- **Signal vocabulary:** the minimal set of `%signals` (redirect, cookie, status, content-type,
  cache, no-store) — enumerate from what controllers actually do today (grep the `print
  $...->header` / redirect / cookie sites).
- **Page content contract:** what a page controller returns post-`PageState` (just `content`, or
  `content + signals`?), and how the shell hydrates (inline payload vs a second fetch).
- **Compression ownership:** today `optimally_compress_page` runs in the controller/router print
  path; in return-based mode it moves into `Everything::Response` (or stays at the app.psgi edge —
  Apache already compresses at the proxy, so possibly drop it app-side entirely).
- **Capture deletion gate:** the capture can only be deleted when *nothing* prints. Track the
  remaining print sites as the burn-down list.
