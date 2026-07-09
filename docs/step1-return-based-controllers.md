# Step 1 — Return-based controllers (retire the STDOUT capture)

**Status:** DONE (1a + 1b + 1c, 2026-07-09) — the STDOUT capture is deleted; both request paths are
return-based. · **Created:** 2026-07-08 · Prereq for the composer/dispatch-table arc in
[api-driven-architecture.md](api-driven-architecture.md).

## Why this first

Everything downstream — in-process content composers, SSR-embed-instead-of-render-harvest, the
generated `node_id/type → \&compose` dispatch table — rides on one primitive: **a controller returns
its response instead of printing it.** Until the page path returns a value app.psgi can finalize, SSR
can only get a page's content by *rendering the whole thing to STDOUT and parsing the bytes back*
(the wasteful `route_node` harvest `/api/pagestate` uses today). Step 1 removes that.

## Current state — half done already

**API path: DONE (return-based, capture-immune).**
- `Everything::APIRouter::dispatcher` → `output` → `Everything::Response->from_cgi_parts($headers,$body)`
  and **returns** it (APIRouter.pm:49-70).
- `app.psgi` checks `$APIr->is_response($returned)` and `return $returned->finalize` — the API response
  never touches the STDOUT capture, so it's immune to the #4237 capture-poisoning class.
- `Everything::Response` exists: CGI-compatible adapter (`cgi_header`/`cgi_redirect`/`format_cookie`)
  **plus** a clean object surface (`status`/`content_type`/`set_header`/`set_cookie`/`redirect`/`body`)
  + `finalize` → a real PSGI triple. `t/126` pins cookie/header byte-equivalence.

**Page path: still prints into the capture.**
- `mod_perlInit` (HTML.pm:747) runs the page render; the body is accumulated as a **single string**
  (`$page`, HTML.pm:352/371) and emitted via `$query->print(...)`. app.psgi captures STDOUT into `$body`
  and `_cgi_output_to_psgi($body)` parses it back to a PSGI triple.
- `app.psgi` is already **dual-mode**: return-based API fast-path + printed-capture page fallback. The
  capture is deleted *last*, once the page path returns instead of prints.

## What Step 1 does

Make the page path **return an `Everything::Response`** (like the API path), then delete the capture.
The wrapper the API side already uses (`from_cgi_parts`) is the drop-in: the page path builds the same
header args + `$page` body it does now, but `return`s a Response instead of `$query->print`-ing it.

## Touch-point inventory (grounded)

The good news: the page **body is one accumulated string**, and most of the raw print count is *not*
in the request-render path.

**In-path emission sites → convert to `return Everything::Response->...`:**
| Site | HTML.pm | What it emits |
|---|---|---|
| Main page | ~the `$query->print($page)` of the built shell | the React shell / full page body + headers |
| Head-optimized short-circuit | 345-349 | `Status`/`Content-Type`/`X-E2-Head-Optimized`, `return` |
| 404/403 | 340-343 | status only |
| Redirect (303) | 510-518 | **already builds `Everything::Response->cgi_redirect`**, then prints it — just return the object |
| Maintenance | 751-752 | `Content-Type` + message |
| SITE_UNAVAILABLE | 766 | `$query->print($SITE_UNAVAILABLE)` |
| Error | 124 | `$query->print($errorHeader.$errorText)` |

**NOT in the page-render path (don't block capture deletion):** the 15 `Application.pm` prints are
`regenerateSearchwords` batch output (894-967), `$elog` file logging (3787), and call-stack debug
(3864-3870). `Delegation/htmlcode.pm`: **0** prints (htmlcode migration already cleared it).

So the real conversion surface is **~7 HTML.pm emission sites over a single string body** — much smaller
than a raw `grep print` implies.

## Incremental plan (each independently shippable)

1. **1a — redirect + short-circuits (smallest, safest).** Convert the 303 redirect (already a
   `Response` object — just `return` it up instead of print), the 404/403, maintenance, and
   SITE_UNAVAILABLE sites to return a `Response`. Thread the return out of `mod_perlInit`; app.psgi's
   page branch does `$returned = mod_perlInit()` and reuses the existing `is_response`/`finalize` edge.
   Low risk: these are terminal paths with tiny bodies.

   **Threading choice (as-built, #4483):** instead of threading a return *value* up through
   `displayPage → gotoNode → handleUserRequest → mod_perlInit` (invasive), emission sites **stash the
   `Response` on `$REQUEST->response`** (the same request-stash pattern E2 uses for `pagestate_e2`);
   `mod_perlInit` returns `$REQUEST->response` at the end (undef if nothing stashed → app.psgi falls
   through to the capture). Fully backward-compatible dual-mode: each site converts independently.

   **Progress:**
   - [x] Plumbing: `Everything::Request` gains a `response` stash; `mod_perlInit` returns it; app.psgi
     page branch captures it (`$returned = mod_perlInit()`). Behavior-neutral until a site converts.
   - [x] **First site: the `gotoNode` `lastnode_id` 303 redirect** (HTML.pm:513). Verified return-based:
     `curl /node/<e2node>?lastnode_id=999` → clean `303` + `Location` (canonical, no lastnode_id) +
     `Cache-Control`, finalized directly (no capture). Full e2e suite green (138 passed, 0 fail).
   - [x] Remaining short-circuits: both HEAD fast-paths (`displayPage` + `gotoNode`) → header-only
     `Response`; maintenance + SITE_UNAVAILABLE (`mod_perlInit`-level) → **return the `Response`
     directly** (they run before/around `$REQUEST`; SITE_UNAVAILABLE now a correct **503**). The
     `$SIG{__DIE__}` error page is intentionally **left on the capture fallback** (die-unwinding vs
     app.psgi's eval makes return-based risky there; dual-mode covers it).

2. **1b — the main page body: DONE.** The single shared emission point is `Everything::Router::output`
   (every controller → `route_node` → `output`), which builds `($headers,$body)` via
   `_build_response_parts`. Converted its `print $header; print $body` → `$REQUEST->response(
   Everything::Response->from_cgi_parts($headers,$body))`. One site, all page types. Byte-equivalent by
   construction — the API path already returns the SAME builder's output via `from_cgi_parts`, pinned
   by `t/131`.

### Validation (2026-07-09)
- **`t/131` + `t/123` pass** (the `from_cgi_parts` == header+print byte-equivalence + request/response
  contract). **`t/000` health + full perl suite green** except the single known ~1yr baseline `t/104`.
- **Response envelope byte-identical:** golden-master over 5 representative pages — **headers + status
  byte-identical**; **4/5 contentData byte-structurally identical**; the lone `home` diff is `bestofweek`
  (a cached feed reset by the rebuild between snapshots — deterministic within a build, and structurally
  impossible for an emission-layer change to touch). E2 pages are inherently non-deterministic (Perl
  hash-order in JSON), so exact md5 golden-master is not the right tool — structural + `t/131` are.
- **Full e2e suite green: 138 passed / 11 skipped**, across every page type + HEAD + redirects.
- **Permanent lock:** `tests/e2e/return-based-page-path.spec.js` (3 tests) — normal page 200 text/html;
  HEAD fast-path status + `X-E2-Head-Optimized` (404 for not-found); `lastnode_id` 303 + Location +
  `no-store`.

**Net: 1a + 1b complete and validated. The STDOUT capture stays (dual-mode) as the fallback for the
error path + anything unconverted — 1c (delete the capture) is the deliberate next step, gated on a
sweep proving nothing else prints in-path.** The two remaining in-path printers to clear before 1c:
the `$SIG{__DIE__}` error page (HTML.pm:124) and a sweep for stragglers.

### 1c — DELETE the capture (2026-07-09, DONE)

**The straggler sweep (prove-then-delete).** Instrumented app.psgi to `warn STRAGGLER_PRINT` whenever
the return-based path fired *and* the capture had ALSO caught bytes (= something printed in-path), then
ran the full e2e suite + every page type through it. Result: **76 stragglers, all on `/api/*`
(`/api/sessions/create`, `/api/users/confirm`), ZERO on any page path.** The page render path never
prints — post-1b it always stashes a Response via `Router::output` or a 1a short-circuit.

**The one printer that mattered — `Everything::Request::login` (Request.pm:277/297).** On a credentialed
login (only the API `/sessions/create` + `/users/confirm` flows; the page path calls `login()` *with a
cookie* so the `unless($cookie)` block is skipped) it did `print $self->header({-cookie=>...})` INTO the
capture *and* `add_response_cookie($login_cookie)`. The print was a vestige of the old page-path
`opLogin`, which is gone (#4335) — the cookie already reaches the client via `response_cookies` →
`APIRouter::output` → the returned Response (the printed bytes were discarded). **Deleted both prints;**
kept `add_response_cookie`. Verified: `POST /api/sessions/create` still returns exactly one `Set-Cookie`
+ the `no-store` Cache-Control. (Left alone: the dead `Application::confirmUser`→`updateLogin`→
`HTML::oplogin()` chain — zero callers, references a removed sub, unrelated cleanup.)

**The `$SIG{__DIE__}` error page needed NO conversion.** `HTML::handle_errors` re-throws while inside an
eval (`CORE::die(@_) if $^S`, HTML.pm:103), and `mod_perlInit`/`$APIr->dispatcher` always run inside
app.psgi's `eval`. So a render die unwinds straight to that eval, which builds a fresh `[500,…]` — the
error response never consulted captured bytes. The `$query->print($errorHeader.$errorText); exit;` branch
is unreachable under PSGI (it needs `$^S` false, which never holds during a request). Capture-independent.

**Deleted the capture machinery (app.psgi).** Gone: the `open my $capture, '>:raw', \$body` block, the
`local *STDOUT = $capture` + `select STDOUT` #4237 re-assert dance, both `close $capture`, the
`_cgi_output_to_psgi($body)` fallback call, and the `_cgi_output_to_psgi` sub itself. The handler
collapses to symmetry with the API path: run inside the eval → `if (is_response($returned)) { return
$returned->finalize }` → else a **loud 500** (a controller that neither emitted nor died is a bug; no
silent empty-200). **Payoff:** the #4237 capture-poisoning class is now *structurally* impossible for
every request — there is no per-request capture handle to leave selected or to close out from under a
later print. The page path was already finalizing its stashed Response post-1b, so removing the
capture changed nothing on it; the only behavioral deltas are the deleted (already-discarded) login
print and the retired select-dance.

**Validation (2026-07-09):** rebuilt capture-free →
- boot smoke: 5 page types 200 w/ real bodies; **`Accept-Encoding: gzip` body `gzip -t`-clean**
  (the ERR_CONTENT_DECODING binary risk the raw capture guarded — still intact via the Response);
  HEAD fast-path 200 + `x-e2-head-optimized:1`; `lastnode_id` 303 + canonical Location; API login one
  `Set-Cookie`.
- **full e2e suite green: 141 passed / 11 skipped.**
- **full perl suite green** except the single known ~1yr baseline `t/104` (t/131 + t/123 Response
  contracts pass within the run).

**Net: the STDOUT capture is gone. Both request paths are return-based and finalize an
`Everything::Response` directly. #4237 is closed for the whole request surface, not just the API.**
2. **1b — the main page body.** `return Everything::Response->from_cgi_parts($header_args, $page)`
   instead of `$query->print($page)`. Body is already a string; this is the bulk of real traffic.
   Verify byte-equivalence to the capture path (see Testing).
3. **1c — delete the capture.** Once `mod_perlInit` always returns a `Response` and a sweep confirms no
   stray in-path `print`, delete `_cgi_output_to_psgi` + the STDOUT capture block in app.psgi. The page
   path becomes capture-immune like the API path (closes the #4237 class for pages too).

## Risks / things to get right

- **Binary/compressed body.** `$page` can be a br/gzip/zstd-compressed **binary** body (app.psgi
  captures *raw bytes* for exactly this reason). The `Response` must carry those bytes verbatim + the
  `Content-Encoding` header — no `:utf8` re-encode (the ERR_CONTENT_DECODING_FAILED footgun).
- **Headers / cookies / redirect.** Auth `Set-Cookie`, cache-control, and the 303 `Location` must
  thread through. `from_cgi_parts` already parses CGI-style header text → `Response`; `t/126` pins it.
- **`select`/#4237.** Return-based is *immune* by construction (never enters the capture) — that's the
  payoff, and it lets us drop the `select STDOUT` re-assert dance for the page path in 1c.
- **Stray prints in the render stack.** 1c can only land after a sweep proves nothing in the
  `mod_perlInit` call graph prints to STDOUT on a normal request. Add a guard (e.g. a tied STDOUT that
  dies on write during a return-based render) in a test build to flush stragglers.

## Testing

- **Return == capture byte-equivalence.** The core assertion (per api-driven-architecture.md): for a
  representative set of nodes/displaytypes, the `Response->finalize` triple is field-for-field equal to
  what `_cgi_output_to_psgi` produced from the captured bytes. Lock this before deleting the capture.
- **`t/126`** already pins Response cookie/header equivalence.
- **Full e2e suite** (real browser page loads across themes/pages) proves no regression on 1b/1c.

## Open question (from api-driven-architecture.md, settle before 1b)

Enumerate the cache-header set the page path actually emits today (`no-cache`/`no-store`/private/…) by
grepping the emission sites, so the `Response` builder reproduces them exactly rather than guessing.

## Relationship to the endgame

Step 1 is *only* the return primitive. Once it lands: a page controller's `buildReactData`/`display`
becomes a value the framework can (a) embed in the SSR pagestate blob in-process and (b) serve as JSON
to the client router — the same composer, two callers. That's what makes the composer-as-API-method,
the self-documenting per-node binding, and the eventual `node_id/type → \&compose` table possible.
Nothing above requires per-page roles or new module weight.
