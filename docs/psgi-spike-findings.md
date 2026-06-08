# PSGI Wrapper Spike — Findings (2026-06-07)

First spike of the PSGI migration (plan step 1). Goal: prove `app.psgi` can bridge a PSGI
`$env` to E2's CGI-style entry points (`mod_perlInit` for pages, `APIRouter->dispatcher` for
the API) with **no `ecore/` changes**, running under plackup/Starman in dev.

Artifact: [`app.psgi`](../app.psgi) at the repo root. Run it with:
```
/var/libraries/bin/starman --workers 2 --listen :5000 app.psgi
```

## What works ✅

- **Page path (`mod_perlInit`) is fully working** under both **plackup** and **Starman**.
  - `GET /`, `/node/N`, `/title/...` all return **200**.
  - **Byte-parity** with the live mod_perl output: PSGI served 19174 bytes vs Apache's 19106
    for `/` (the ~68-byte delta is dynamic content; both render the same page, headers, status).
  - Zero `ecore/` changes — the wrapper just bridges `$env → %ENV`, aliases `psgi.input → STDIN`,
    captures STDOUT, and parses the CGI response into a PSGI triple. **The core migration thesis
    holds: PSGI is a different harness around the same entry point.**
- **API routing works** — `/api/*` is correctly dispatched to `APIRouter->dispatcher` (verified the
  branch fires and returns `Content-Type: application/json`), everything else to `mod_perlInit`,
  mirroring the Apache split.
- The startup perl-5.40 `encodeHTML`/`parseLinks` deprecation warnings (#4222) appear but are
  non-fatal — same as under mod_perl.

## API path — FIXED ✅ (root cause was SCRIPT_NAME, not CGI globals)

The API initially returned **405 Method Not Allowed**. Root cause was *not* CGI global state — it
was **`SCRIPT_NAME`**. `Everything::Request::_build_cgi` branches on it:

```perl
if ($ENV{SCRIPT_NAME}) { $cgi = new CGI; }        # correct: reads the live request
else                   { $cgi = new CGI(\*STDIN); } # wrong: reads CGI from a filehandle
```

Apache sets `SCRIPT_NAME` to the full request path (truthy). **PSGI leaves it empty** (path is in
`PATH_INFO`), so `_build_cgi` took the wrong branch, CGI never read the real request, and
`request_method` came back empty → the dispatcher's `grep {$method} (...)` guard 405'd. (The page
path survived only because a GET front page needs no params.)

**Fix (wrapper-only):** remap the CGI env to Apache's shape — `SCRIPT_NAME` = full request path,
`PATH_INFO` = `''`. Result: `/api/sessions` now returns `{"display":{"is_guest":1}}` — **byte-identical
to Apache** — and the page path still has full parity.

### SCRIPT_NAME / PATH_INFO consumer audit (why the remap is safe everywhere)
- `Request.pm:93` `_build_cgi` — the branch above. Fixed.
- `HTML.pm:1012` — gates printing the response HTTP header on `SCRIPT_NAME`; truthy → emits headers
  matching Apache (empty would have skipped them — the page was silently relying on the wrapper default).
- CGI `url()` (the dispatcher's `url(-absolute=>1)`) — uses `SCRIPT_NAME`; the full-path remap makes it
  return the request path, which is what routing needs. Confirmed by the API routing correctly.
- `www/index.pl:3` — dead under PSGI (the wrapper is the entry point).
- `PATH_INFO` — read nowhere in the codebase (no `$ENV{PATH_INFO}`, no `->path_info` callers); blanking safe.

## CRITICAL bug found + fixed: cross-request state bleed 🛑→✅

Surfaced while validating legacy `/index.pl?node_id=N` SEO URLs against the Apache→Starman proxy.
**The same URL returned different pages on each request** — cycling through the *previous* requests'
renders (with 5 Starman workers, each worker echoed whatever it last served). mod_perl was rock-stable.

Root cause: **CGI.pm caches the parsed request in package globals.** Under mod_perl, `ModPerl::Registry`
resets them every request; under a bare PSGI server **nothing does**, so a fresh `new CGI` returns the
*prior* request's query — serving the wrong node, wrong user, and **leaking one user's data to another**.
This is the #1 ship-blocker and would never be caught by single-request smoke tests.

**Fix:** `CGI::initialize_globals() if CGI->can('initialize_globals')` at the very top of every request
in `app.psgi`. After it: `node_id=529746` → "Cool Archive" ×6 stable, and a full PSGI-vs-mod_perl parity
sweep (front page, `/title/`, `/node/`, and every legacy `/index.pl?node=` / `?node_id=` shape) is **100%
matching**. Lesson: **any per-request global the mod_perl lifecycle reset for free must be reset explicitly
in the wrapper** — interrogate `NodeCache`/`$USER`/other package state the same way under sustained load.

## Apache→Starman proxy topology (validated)
`<IfDefine E2_PSGI>` in `apache2.conf.erb` (toggled by the `E2_PSGI` env in `apache2_wrapper.rb`): Apache
serves static from DocumentRoot and proxies all dynamic (pages + `/api`, via `RewriteCond !\.pl$` so
`/index.pl?...` proxies with query preserved) to a supervised Starman on `127.0.0.1:5000`. mod_perl path
untouched when the flag is off. Next: flip to `mpm_event` + fully gate out mod_perl (stage 2), then load-test.

## Still to validate (next)
- POST/PUT bodies (writeup post, login) — exercises the `psgi.input → STDIN` bridge.
- `Set-Cookie` round-trip (login → authenticated request).
- Per-request CGI state under heavy worker reuse (no leakage across requests on the same worker).

## Operational gotcha (cost me time, worth recording)
- A stale `plackup`/`starman` holding `:5000` makes every "restart" silently die with
  `Server closing!` (port bind fail) — and you keep testing the **old** code. Always
  `fuser -k 5000/tcp` + confirm the port is free before relaunching during dev iteration.

## Next steps (spike → Phase A completion)
1. Fix the CGI-reset so the API path returns real responses (then re-run an API parity check).
2. Exercise POST/PUT bodies (writeup post, login) — validates the `psgi.input → STDIN` bridge.
3. Validate `Set-Cookie` round-trip (login → authenticated request).
4. Decide: hand-rolled bridge vs `CGI::Emulate::PSGI` (robustness vs. one more dep — already
   re-vendoring-friendly now that Plack is in the bundle).
