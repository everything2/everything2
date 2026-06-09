# Plack::Request migration — autonomous run progress log

**Started:** 2026-06-09 (overnight autonomous session, ~12h mandate)
**Plan of record:** [docs/plack-request-migration.md](plack-request-migration.md)
**Working rule:** strictly additive / non-breaking; site stays on CGI behaviour until a
flip is proven green (parity harness + full perl suite + e2e + load test). No commits — all
changes left in the working tree for review. Health-check path (`www/health.pl` +
Apache `<Location /health.pl>`) deliberately untouched (ELB dependency; defer to review).

## Surface (re-verified 2026-06-09, cite-then-trust)
- `$query->param(` reads: **410**  ·  `$REQUEST->param(` façade: **71**  ·  any `->param(`: 604
- `->cgi->` bypasses: **30** (messages 14, chatter 4, category/client_errors 3 each, signup/users 1, Request 3, 1 page)
- mutation-ish: ~35  ·  `->Vars`: **5**  ·  CGI form-helpers: **9**  ·  `new CGI`: **4** (2 are the seam)
- response-gen via request: HTML.pm:1024 (`header`), Request.pm:181/199 (`print header` login cookie),
  Router.pm:63 (`print header`). These are the **response epoch** (Phase 4) — NOT touched tonight.

## Status legend
✅ done & green · 🚧 in progress · ⏸ staged for review (not live) · ⛔ deferred (needs user)

## Steps

### ⛔ Phase 0 — dead-code removal — DEFERRED
- `www/health.pl` + Apache `<Location /health.pl>`: app.psgi already answers `/health` & `/health.pl`
  directly, and mod_perl is gone so health.pl can't execute — but this is the **ELB health path**.
  Too risky to remove unsupervised. **Action for review:** confirm ELB → Apache → Starman `/health`
  path, then drop health.pl + the Apache Location block together.
- CGI form-helpers (9) / other dead consumers: cataloged, not yet verified dead. Deferred.

_(subsequent steps appended below as completed)_

### ✅ Prerequisite — PSGI env threading + additive Plack::Request `req` backing
- `Everything::Request`: added `our $PSGI_ENV`, `psgi_env` (threaded env or %ENV fallback),
  lazy `req` (Plack::Request). CGI backing unchanged & primary.
- `app.psgi`: `local $Everything::Request::PSGI_ENV = $env;` per request.
- Test **t/122** (5 subtests) — req parses query/method/cookies/headers; %ENV fallback. GREEN.

### ✅ Phase 1 — CGI↔Plack read-surface parity harness (t/123)
- 18-case corpus + POST body + cookies + methods. **Key finding: CGI `-utf8` and Plack::Request
  return BYTE-IDENTICAL reads** for UTF-8 (incl. 4-byte emoji/CJK), `;` separators, plus-as-space,
  encoded specials, multi-value, empty. The decoding risk the design feared is absent.
- **One real divergence pinned:** scalar `param()` on a multi-value key — CGI returns the FIRST
  value, raw `Plack::Request->param` the LAST. The reader contract is **first-value** (`get_all[0]`).
  Harness GREEN (21 subtests) asserting reader==CGI.

### 🚧 Backing flip — `Everything::Request::PlackQuery` (Plack-backed CGI drop-in)
- DECISION: parse 100% via Plack (CGI out of request path); empty `CGI->new("")` kept ONLY as
  output formatter for header/redirect/cookie-gen/form-helpers (no body read → no conflict).
- CGI method surface to cover: param(read first-value/set), multi_param, Vars(\0-join), cookie
  (read→Plack / gen→fmt), request_method, script_name/path_info/url, user_agent, delete/delete_all,
  escape, upload/uploadInfo (Plack uploads — the live homenode-image path, API/user.pm), header/
  redirect/print/forms (→fmt). app.psgi must thread a SCRIPT_NAME/PATH_INFO-remapped env copy so
  Plack's path matches CGI's (the %ENV remap).
- Final `use CGI` removal (hand-roll the formatter) = documented follow-up, gated on byte-parity.

---

## ✅ MILESTONE REACHED — CGI.pm is out of the request-parsing path

**Status (end of overnight session): the backing flip is DONE and fully validated.**
The request is now parsed entirely by Plack::Request (`Everything::Request::PlackQuery`);
CGI.pm no longer parses any request. The site behaves identically.

### What changed (all in the working tree, NOT committed)
- **`ecore/Everything/Request/PlackQuery.pm`** (NEW) — Plack-backed CGI drop-in. Reads
  (first-value `param`, `multi_param`, `Vars` \0-join, cookie-read, `request_method`,
  `script_name`/`path_info`/`url`, `user_agent`), a CGI-faithful mutable param table
  (`param`-set/`delete`/`delete_all`), `escape`, `upload`/`uploadInfo` (Plack uploads), and
  output (`header`/`redirect`/`print`/cookie-gen/form-helpers) delegated to an **empty**
  `CGI->new('')` formatter (no body read → no consumption conflict).
- **`Request.pm`** — `_build_cgi` now returns a PlackQuery sharing the one `Plack::Request`;
  added `req`/`psgi_env`; `cgi` isa → PlackQuery; **POSTDATA for JSON POST now reads
  `$self->req->content`** (CGI's `param('POSTDATA')` pseudo-param doesn't exist in Plack — this
  was THE critical fix; every JSON-body endpoint, incl. login, depends on it). `use CGI` removed.
- **`app.psgi`** — threads a SCRIPT_NAME/PATH_INFO-remapped PSGI env copy to `Everything::Request`.
- **`HTML.pm`** — the canonical-303-redirect clone `new CGI($query)` (couldn't clone a PlackQuery)
  → copy `$query`'s params into a fresh CGI (GET-only redirect path).
- **`API/user.pm`** — homenode image upload reads the Plack upload's spooled `->path`.
- **`API/writeups.pm`** — one-line critic fix (mixed boolean), unrelated to the flip.

### Tests added (4 files, ~90 assertions)
- **t/122** — req backing wired from threaded env (+%ENV fallback).
- **t/123** — CGI↔Plack read-surface parity harness (18-case corpus + POST/cookies/methods).
  Pins the **first-value `param`** rule (the one real divergence).
- **t/124** — PlackQuery parity vs CGI: reads, mutation, Vars, cookie, multipart upload, formatter.

### Validation (all GREEN)
- Request-layer tests: **44 pass**.
- **Full prove suite (130 files, 4352 tests): zero flip regressions.** Every remaining failure
  (t/002:10, t/018:29-30, t/036:7, t/049:9/13/16, t/101:17) fails identically on master.
  The flip actually *fixed* t/000 (latent Perl::Critic issues cleaned up).
- **Full Playwright e2e: 88 passed, 0 failed.** (3 transient failures during the run were: 2
  canonical-303 redirect bugs — FIXED by the HTML.pm clone fix; 1 New-Writeups link — traced to a
  stale `DataStash::newwriteups` cache holding my own t/121 test fixtures, purged + regenerated,
  then 29/29. Not a flip issue: real titles resolve fine.)
- **Load test: 0 errors (non2xx=0)** across conc 1→50, ~880 req/s pages, p99 23–77ms.
- React: 1590 pass (untouched).

### ⏭ Follow-up to FULLY remove CGI.pm (scoped, for review — NOT done tonight)
CGI is still *loaded* for two non-request-path reasons; removing it is a clean follow-up:
1. **`CGI::escape` (8 sites:** Application.pm ×5, Node.pm ×2, debatecomment.pm ×1) — URL-escape
   utility. Replace with `URI::Escape::uri_escape`, parity-tested per call (escaping tables differ
   subtly, so test before flipping).
2. **`CGI::Carp`/`set_die_handler` (HTML.pm)** — error handler; swap for a plain `$SIG{__DIE__}`.
3. **Response formatter** — the empty `CGI->new('')` in PlackQuery (+ the HTML.pm redirect clone)
   does `header`/`cookie`/`redirect`/form-helper formatting. Hand-rolling these (the "response
   epoch" in the design doc) retires the last `use CGI` and is best sequenced with the
   Everything::Response work. Gate on byte-parity tests against CGI's output.

Also still open from the design doc: param-mutation→immutable model migration (the 4 `delete`
sites + handleUserRequest), and the Everything::Response / PageState epochs. The request-layer
flip — the foundational, highest-risk piece — is the part that's now done and proven.

## ✅ BONUS — `CGI::escape` → `URI::Escape` (3 more modules off CGI)
`URI::Escape::uri_escape` is **byte-identical** to `CGI::escape` for E2's URL-gen inputs
(verified across UTF-8 / `&` / `+` / `/` / `;` / `?` / specials — t/125). Migrated the 6 call
sites; **`use CGI` removed from Application.pm, Node.pm, Controller/debatecomment.pm** (those used
nothing else from CGI). Validated: t/125 parity, e2e link-resolution + url-routing 43/43, critic
clean, full prove (only the known flaky message/chatter/room tests + pre-existing baseline; all
pass in isolation).

**CGI is now loaded by only TWO places, both response-formatting (not request path):**
HTML.pm (`CGI::Carp` die handler + the redirect-clone formatter + `$query->header`) and
`PlackQuery` (the empty `CGI->new('')` formatter). Retiring those = the response epoch (sequenced
separately; gate on byte-parity). That's the last mile to deleting CGI.pm outright.

## Final working-tree state (all uncommitted, for review)
Modified: app.psgi, Request.pm, HTML.pm, API/user.pm, API/writeups.pm, Application.pm, Node.pm,
Controller/debatecomment.pm. New: Request/PlackQuery.pm, t/122–125, this doc + the design doc.
No commits made (per standing policy). Suggested review order: Request.pm + PlackQuery.pm (the
core flip) → app.psgi (env threading) → HTML.pm (redirect clone) → the escape swap → tests.

---

## ✅ RESPONSE EPOCH (night 2) — CGI.pm fully deleted from the application

`Everything::Response` (new) is now the response authority; **CGI.pm no longer loads into the
app at all** (verified via %INC after loading the whole framework). The request layer (night 1)
and the response layer (night 2) are both CGI-free.

### What changed
- **`ecore/Everything/Response.pm`** (NEW) — wraps Plack::Response. CGI-compatible adapters
  (`cgi_header`/`cgi_redirect`/`format_cookie`, the latter via `Cookie::Baker`) produce the
  byte-equivalent output the print/STDOUT-capture flow expects, so the migration is a drop-in.
  Also the clean object surface (`status`/`set_cookie`/`redirect`/`body`/`json`/`html`/`finalize`)
  — `finalize` is a real PSGI triple, the seed of return-based responses.
- **`PlackQuery`** — `header`/`redirect`/`cookie`-gen now go through `Everything::Response`;
  `escape`→`uri_escape`; form-helpers hand-rolled (no CGI). Dropped the empty-CGI formatter.
- **`HTML.pm`** — page header + the canonical 303 redirect go through `Everything::Response`
  (the redirect no longer clones a CGI object — a plain param hash now); `CGI::Carp` die handler
  → `$SIG{__DIE__}` + `$^S`; `use CGI`/`use CGI::Carp` removed.
- **`NodeBase.pm`** — `CGI::unescape` (an implicit dep with no `use CGI`! caught by the %INC
  check — would have crashed the title-lookup hot path) → inline `+`→space + `%XX` decode.
- Login cookie path unchanged at the call sites: `make_login_cookie` → `$self->cookie(-name=>...)`
  → `PlackQuery->cookie` → `Everything::Response->format_cookie` → `Cookie::Baker`. The only
  visible diff is the cookie expires date renders dashed (Netscape) vs CGI's spaced (RFC1123) —
  both browser-valid (Jay: "don't worry about byte-identical fields for browser-fuzz that works").

### Tests
- **t/126** (NEW, 11 subtests) — `Everything::Response` cookie byte-parity (expires normalized) +
  header/redirect semantic parity vs CGI + `finalize` PSGI triple.
- t/124 output subtest relaxed from byte-match-CGI to semantic (clean output now).

### Validation (all green)
- Request + response tests pass; **CGI.pm not in %INC** after full framework load.
- Full prove suite: only pre-existing/flaky failures (t/002:10 'Returns JSON', t/018:29-30,
  t/049, t/101:17, and the `-j4` flaky t/036/038/043/053/069). **Login proven working** —
  t/002 test 9 (200) + test 11 (Set-Cookie) both pass.
- **e2e 88/88** (the one transient link-resolution failure was, again, the stale
  `DataStash::newwriteups` cache holding t/121 fixtures — purged + regenerated → 29/29; t/069's
  `writeup_type` failure was the same fixture pollution, cleared by the purge).
- **Load test: 0 errors** across front-page/node/title/api/static at conc 1→50.

### ⏭ Deferred (Jay's "incremental future", documented not done)
- **Return-based responses** (R2): `Router::output` returns an `Everything::Response`; app.psgi
  `finalize`s it for the API path → bypasses the STDOUT capture → immune to #4237. Dual-mode so the
  page path follows incrementally; capture deleted last. This is the first step of "moving HTTP out
  of controllers."
- The 100%-API-driven direction + the granular input/output testing story: **docs/api-driven-architecture.md**.
- t/121 cleanup hardening (it leaks New-Writeups fixtures into the `newwriteups` DataStash, which
  recurs as a flaky e2e/t-069 failure until purged+regenerated). Cheap fix: clean newwriteup +
  regenerate the stash in t/121's teardown.
- Still deferred from night 1: `www/health.pl` removal (ELB path).
