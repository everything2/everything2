# PSGI warning cleanup — captured from prod (2026-06-08 cutover)

Captured from `/aws/events/e2-app-errors` (the `global_warn_handler` sink) over the
first clean PSGI window after the #4235 cutover (2026-06-08 15:05Z onward). Sample
of 300 consecutive warning events. **Fix on the next bounce.**

Cross-reference: in the same window the ALB showed **32 target 5xx vs 0 under
mod_perl** (14:00–14:55Z). Warnings #1/#2 are the leading suspect — see "5xx link".

| # | count (of 300) | site | new under PSGI? | severity |
|---|---|---|---|---|
| 1 | 294 | `Everything/Router.pm:63` | **Yes** (by construction) | high |
| 2 | 5 | `Everything/HTML.pm:887` | **Yes** (by construction) | high |
| 3 | 1 | `Everything/API/cool.pm:90` | likely pre-existing | low |

---

## #1 — `print() on closed filehandle $capture` @ Router.pm:63  (294×)

```
print() on closed filehandle $capture at /var/everything/ecore/Everything/Router.pm line 63.
```
- **Method/routes:** GET, on page URLs (`/title/...`, `/node/...`, `/`) — NOT just `/api/`.
- **The line:** `print $REQUEST->header($headers);` — a plain `print` to `STDOUT`.

## #2 — `print() on closed filehandle $capture` @ HTML.pm:887  (5×)

```
print() on closed filehandle $capture at /var/everything/ecore/Everything/HTML.pm line 887.
```
- **Method/routes:** GET pages (`/`, `/title/...`).
- **The line:** `print $redir_header if $ENV{E2_PSGI};` — the canonical-303 redirect
  fix; also a plain `print` to `STDOUT`.

### Why #1 and #2 are PSGI-born
`$capture` is the per-request scalar-backed STDOUT capture in
[app.psgi](../app.psgi) (`open my $capture, '>:raw', \$body; local *STDOUT = $capture`).
It does not exist under mod_perl, so a "print on closed filehandle **$capture**"
warning is structurally impossible there — these are pure cutover regressions.

### What the warning means
Both sites are ordinary `print` (to `STDOUT`). The warning means that at print time
`STDOUT` is aliased to a **closed** `$capture` — i.e. a capture handle from a
*previous* request on the same persistent Starman worker, not the live one. Perl
names the closed IO handle (`$capture`) in the warning regardless of how the alias
was reached. Net effect: that print's bytes go to a dead handle and are **lost**,
while the current request's `$body` is missing those bytes.

### 5xx link (hypothesis, not yet confirmed)
If the lost bytes are the response **header** (Router.pm:63) or a **303 redirect**
header (HTML.pm:887), the current request's captured `$body` is header-less or
empty → `_cgi_output_to_psgi` produces a malformed/empty response. That is a
plausible mechanism for the 32 target 5xx (or, worse, silent blank/truncated 200s).
**To confirm:** correlate the 5xx request URLs from the ALB S3 access logs
(`elblogs.everything2.com`) against these warning URLs. ELB-level 5xx was 0, so
whatever it is originates at the Apache/app target, consistent with this.

### Fix direction
Root-cause the stale capture handle — something is letting a reference to (or an
alias of) one request's `$capture`/`STDOUT` survive into the next request on a
preforked worker. Candidate areas:
- a persisted `STDOUT` reference / `select()` left set by `mod_perlInit` or the API
  dispatcher (E2 globals that mod_perl used to reset per-request but Starman does not);
- making app.psgi's capture robust to that — e.g. save/restore via `select`, or
  guarantee no app-held handle outlives the `local *STDOUT` block.
Once fixed, the e2e suite should gain a check that a captured page/redirect response
body is non-empty and header-complete (the current suite did not catch this).

---

## #3 — `Argument " " isn't numeric in int` @ API/cool.pm:90  (1×)

```
Argument " " isn't numeric in int at /var/everything/ecore/Everything/API/cool.pm line 90.
```
- **Method/route:** POST `/api/cool/writeup/<id>`.
- Benign input-validation gap: an empty/space arg reaching `int()` in `award_cool`.
  Almost certainly a malformed/bot request; not PSGI-specific. Low priority — guard
  the arg with a numeric check before `int()`.
