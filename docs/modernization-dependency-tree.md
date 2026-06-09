# Everything2 Modernization — Epoch Tree

**Last updated**: 2026-06-09
**Maintainer**: Jay Bonci

> **The two hard roots are cleared.** `epoch:mysql-8.4` (migrated 2026-06-07, #4226) and
> `epoch:psgi` (live in prod 2026-06-08) are **done** — so the post-PSGI cleanups this tree lists
> as *blocked* are now the **active frontier**, and CGI.pm has since been removed entirely
> (#4230). The current center of gravity is the request/response modernization → 100%-API-driven
> move (see `docs/api-driven-architecture.md`).

> **★ Near-top cost priority — #4246 (cron sidecar).** The dedicated cron Fargate tasks
> (`e2cron-family`) measure at **~$70/mo (~$840/yr), ~half the Fargate+IPv4 bill** — driven by
> `datastash` at `rate(2m)` running effectively 24/7. Collapse the 8 EventBridge→`RunTask` rules
> onto the (overprovisioned) webheads via a `GET_LOCK`-elected cron sidecar; near-zero marginal
> cost, frees ~4 public IPs, and fixes a latent overlap bug. Unblocked by PSGI (hooks into the
> Starman entrypoint). Cheap pre-step: `datastash` `rate(2m)`→`rate(10m)`. Design:
> `docs/cron-sidecar-design.md`.

The map of where deferred work lands and what depends on what. Two axes:

- **Epoch label** (`epoch:*` on the GH issue) = *which workstream owns it* (domain/phase).
- **Tree position** (this doc) = *what has to be true before we touch it* (dependency ordering).

An issue can be `epoch:perl-cleanup` **and** blocked by PSGI — the label says who owns it, the tree says when it's reachable. Filter the tracker with `label:epoch:psgi` etc.; read this doc for sequence.

> Maintenance: as backlog issues get tagged (the tranche pass), add them under their epoch here with a one-line hook. Closed-as-obsolete issues don't appear. Cross-check against `git log` — phases drift.

---

## Dependency ordering (the spine)

```
epoch:mysql-8.4   ✅ DONE — migrated 2026-06-07 (#4226). Was the July 2026 hard root
   │                 (RDS engine sunset). Zero-date family + auth-plugin cleared.
   │
   └─> epoch:psgi   ✅ DONE — live in prod 2026-06-08. mod_perl gone, Apache on
         │              mpm_event (#2424), Starman/Plack; DB connections cut ~5×.
         │
         │   ── post-PSGI request/response modernization (the ACTIVE FRONTIER) ──
         │   ├─ ✅ CGI.pm fully removed (#4230) — request + response layers + the dep
         │   │     itself. New: Everything::Request::PlackQuery (request),
         │   │     Everything::Response (response), Everything::HealthCheck (PSGI health
         │   │     app, replaced www/health.pl). CGI dropped from cpanfile + vendor cache.
         │   │     Docs: plack-request-migration.md, plack-request-progress.md.
         │   └─ ▶ NEXT epoch: 100%-API-driven move — controllers return data, HTTP lives
         │         in the response layer. Return-based responses (retire the STDOUT
         │         capture → #4237-immune), PageState chrome/content split, the e2-blob
         │         normalization (#3981 identity de-dup, #4152 int-as-string).
         │         Design: docs/api-driven-architecture.md.
         │
         │   ENABLERS for the broader cleanups (early in the post-PSGI batch):
         │   ├─ sqitch adoption ........ versioned schema migrations (no DBIC needed)
         │   └─ #4178 Globals/Constants/Configuration detangle (perl-cleanup hub)
         │
         ├─> epoch:perl-cleanup   (UNBLOCKED; schema-touching ones need sqitch)
         ├─> epoch:react-cleanup  (UNBLOCKED; SSE ones use PSGI's process model)
         ├─> epoch:infra-cleanup  (apache/deploy; #4129 also needs #4163 settled)
         │      └─ ★ #4246 cron sidecar (GET_LOCK) — ~$840/yr cost cut, do early
         │
         └─> epoch:social-login   (feature; first new table → DBIC carve-out decision;
                                    needs sqitch first)

epoch:user-requests  ── orthogonal; community asks, schedule independently.
epoch:infra-cleanup (security subset, #4182) ── NOT gated on anything; ships now.
```

Key non-obvious edges:
- **sqitch is a hub**: `#4173`, `#4180`, settings→JSON all want versioned migrations. Pull it in as PSGI lands, not "phase 9."
- **`#4178` (Globals) is a hub**: settings→JSON, tombstoning, numwriteups all touch the global/config surface — do #4178 first so they build on clean config.
- **`#4129` depends on `#4163`**: mod_rewrite title-hack removal needs LinkNode's URL shape settled first.
- **`#4182` (security headers) depends on nothing** — Apache `mod_headers` + a 2-line cookie change. Ship independent of the spine.

---

## epoch:mysql-8.4 — ✅ DONE (migrated 2026-06-07, #4226)

Was deadline-gated (July 2026 RDS engine sunset); shipped ahead of it. The zero-date family and
the `everyuser`→`caching_sha2_password` auth-plugin blocker are cleared. Residual non-8.4-blocking
items below (e.g. #4092 PK-less tables, #2210 `ALLOW_INVALID_DATES` removal) are now ordinary
backlog, not deadline work. Original tracking: **#4074**.
- Zero-date family: #4075 node.createtime · #4076 writeup.publishtime · #4077 e2node.updated · #4078 vote times · #4079 weblog · #4080 pollvote · #4081 nodetracker · #4082 notified · #4083 lastreaddebate · #4084 dbstats · #4086 podcast · #4087 roomdata · #4088 nodebak · #4089 heaven  *(— #4085 locktime done; #4090/#4091 tomb/krut evaluated)*
- #4122 — everyuser → caching_sha2_password (hard blocker)
- #4109 — message_outbox columns
- #4092 — promote unique keys to PRIMARY KEY on 5 PK-less tables *(low priority; not 8.4-blocking)*
- #2210 — drop the `ALLOW_INVALID_DATES` sql-mode workaround *(the parent reason for the #4074 zero-date family)*

## epoch:psgi — ✅ DONE (live in prod 2026-06-08)

The PSGI/Plack migration shipped: mod_perl removed, Apache on mpm_event, Starman/Plack serving,
DB connections cut ~5×. Plan: [psgi-plack-migration-plan.md](psgi-plack-migration-plan.md).
- ✅ **#2424 — Apache flipped to mpm_event.** Done (mod_perl gone, prefork tuning removed,
  worker count moved to Starman).
- 🔄 **#3768 — mod_perl overrides non-200 + appends HTML — TRANSFORMS into an API-consistency
  pass.** mod_perl was the thing that mangled non-200 responses (appended HTML, breaking JSON
  clients) — hence the 'API responses must be HTTP 200, return errors as `[HTTP_OK, {success=>0}]`'
  rule. With mod_perl gone, **non-200 responses work correctly now**, so the workaround can be
  lifted: reframe #3768 as bringing the APIs in line with HTTP standards — return proper status
  codes (400/403/404/409/422/…) for errors instead of `200 + {success:0,error}`. Pairs with the
  return-based-response epoch (status becomes a first-class field of `Everything::Response`); the
  CLAUDE.md 200-only rule retires as that pass lands.
- #31 — `ModPerl::Util::exit` called oddly in HTML.pm. The PSGI wrapper rewired exit/STDIN/STDOUT;
  **verify** whether any `ModPerl::Util::exit` / bare `exit` remains in the live path (would kill a
  Starman worker) and convert to a return, then close.

### ✅ Post-PSGI: CGI.pm removal (#4230) — DONE (working tree; not yet committed/PR'd)

CGI.pm removed from the entire application across two threads:
- **Request layer** — `Everything::Request::PlackQuery` (Plack::Request-backed drop-in); the
  request is parsed 100% by Plack::Request. Docs: [plack-request-migration.md](plack-request-migration.md),
  [plack-request-progress.md](plack-request-progress.md).
- **Response layer** — `Everything::Response` (Plack::Response/Cookie::Baker-backed); header/cookie/
  redirect generation no longer use CGI. `finalize` returns a real PSGI triple — the seam the
  return-based-response epoch flips.
- **Health check** — `Everything::HealthCheck` (PSGI app) replaced the mod_perl `www/health.pl`.
- **The dependency** — `CGI` + `CGI::Carp` dropped from `cpanfile`, the tarball + index entries
  pulled from the `vendor/cache` minicpan + `cpanfile.snapshot`. Verified: a clean image build no
  longer installs CGI.pm at all (nothing pulls it transitively).
- Tests: t/122 (req backing) + t/123 (request/response contract) + t/127 (health); the migration
  parity scaffolds were retired once proven.

### ▶ NEXT epoch: 100%-API-driven move

Controllers become pure `(request data) → (response data)`; HTTP lives only in the response layer.
Foundation (`Everything::Response.finalize`) is already in place. Steps: return-based responses
(retire the STDOUT capture → immune to the #4237 bug class) → `PageState` extraction with a
**structural-vs-live chrome** split (the e2 blob out of the `Application.pm` god-method; #3981
identity de-dup, #4152 int-as-string normalization fold in here) → React-owned routing.
**ALB-cost constraint:** deliver bundled (one request/page); the split is a server-assembly +
client-memory optimization, *not* per-endpoint fan-out. Design: [api-driven-architecture.md](api-driven-architecture.md).

## epoch:react-cleanup

- #4171 — consolidate rich/HTML editor mode-toggle
- #4163 — simplify LinkNode (blocks #4129)
- #4117 — chatterbox + other-users → SSE (needs PSGI's process model)
- #23 — review what the print stylesheet (`@media print` + `#printsheet` link) actually produces, esp. under zen
- #117 — e2gle theme: fix busted images vs deprecate + migrate (**10 live prod users**)
- #175 — remove Autoformat JS (believed unused in prod — verify + delete)
- #548 — printable stylesheets still show writeup hints *(print-CSS cluster w/ #23)*
- #528 — make guestuserbanner more helpful · #530 — line numbering + htmlcode linking in code display
- #937 — "Redirected from" message URL-decoding (encoding cluster) · #939 — duplicate pulldown at bottom of writeups
- #1068 — remove dead #metalinks from stylesheets · #1336 — My Chatterlight bug · #1337 — Best Users sidebar chatbox post bug · #1511 — add-to-page responsiveness *(verify in React)*
- #2134 — incomplete JS response (truncation) · #2154 — Cool Man Eddie sharing-button confusion *(#1687 falsy-0 link bug → merged into #4108)*
- #2594 — superdocs render without theme/structure · #2854 — Text Formatter preview broken · #2974 — remove ariaHideApp={false} from Developer nodelet (a11y) · #2988 — Cool Writeups visual glitch
- #3897 — Personal Links blank for some users · #3903 — progress wheels on admin draft ops · #3911 — fetchWithErrorReporting on all fetches · #3921 — softlink URLs inconsistent w/ other node links *(LinkNode)*
- #3981 — de-dup React state already on e2.user (is_admin) · #3982 — expand AdminNothingFoundLink to a create-node UI · #3984 — writeup-edit link atop e2nodes (discoverability)
- #4006 — messages should show newlines · #4007 — mikoyan25-flipped nodelet layout · #4019 — Jukka emulation icons missing *(theme-asset cluster w/ #117)* · #4026 — rich-text editor link behavior · #4030 — lastnode title gone from search box · #4031 — profile pic doesn't update (Android Chrome) *(homenode cluster)*
- #4095 — consolidate duplicated React patterns · #4096 — window.confirm → ConfirmActionModal · #4098 — autosuggest on single-entity inputs · #4099 — bulk newline fields → tag/chip inputs · #4108 — {value && JSX} truthy audit *(absorbs #1687; cluster w/ #4152)*
- **Asset-pipeline remnants** — the DB→S3 CSS migration is **DONE** (#2845/#2846/#2847/#2869 closed); image inlining (#2856) and basesheet-elimination (#2852) also closed (the basesheet *is* Kernel Blue now — themes are thin variable-override zensheets on top; the BEM refactor consolidates structure into it). Remaining nugget: #2832 eliminate customstyle widgetry *(still ~9 files)*

## epoch:perl-cleanup

- #4178 — Globals/Constants/Configuration detangle **(hub — do first)**
- #4173 — drop denormalized numwriteups, derive live *(needs sqitch)*
- #4180 — replace tomb/heaven blob-archive with real soft-delete tombstoning *(needs sqitch)*
- #4167 — clean up entity-encoded node titles + insertion guards
- #1 — e2poll/node duplicate `totalvotes` column (schema cleanup; not 8.4-blocking)
- #24 — `getNode(X,'nodetype')` ≠ `getType(X)` engine semantics (ties to retire-NodeBase)
- #146 — retire old e2 mail nodes · #156 — remove dead jscript maintenance objects
- #159 — force valid salts / harden legacy password storage *(security-adjacent)*
- #224 — don't leak raw error on malformed JSON POST (API error handling)
- #158 — emoji in node title: *verify-by-test* (encoding proven in t/103+t/038; needs title round-trip test, then close)
- #235 — password reset: *verify-by-test* — **no coverage today**; write reset-flow test, fix if it surfaces the 2017 bug *(auth — priority)*
- **2017 messages-API cluster** — #247 #248 #252 #253 #254 #256 #257 #258 #259 #263 *(verify each vs current `Everything::API::messages` in the enrichment pass — recent messaging work likely OBE'd several; #248 maybe covered by #3990)*
- **API/engine test-coverage sub-cluster** — #267 #295 #352 #368 #386 · #4194 t/049 aborts mid-file (unguarded decode_json, no-root-writeup) *(+ verify-by-test #158/#235; one coordinated test push, shared fixtures)*
- **API behavior/validation** — #315 POST-without-POST · #348 NOT_FOUND vs UNIMPLEMENTED · #353 group-member model restriction · #354 usergroup add/del post-limit
- **NodeBase engine** — #363 remove legacy-bug defense · #366 multi-row title lookup *(ties to retire-NodeBase w/ #24)*
- **VARS/data** — #291 numcools contains HTML · #292 cache numcools (ties to #4173) · #268 settings unignore warning · #333 bookmark usergroup attribution
- **signup/reset** — #391 signup dev error · #392 debuggable reset/signup confirmation links (enables #235 test)
- #405 — routechooser caching
- **SEO meta** — #526 meta-robots in user templates · #527 meta-descriptions per type *(t/041 exists — partly done)*
- **session/borged** — #524 borged in session display · #531 cookie storage for GP/borged client notifications
- **nodelet schema dead-columns** — #532 parent_container/updateinterval · #564 nltext
- #591 — node.title → NOT NULL *(ties to no-NULL-on-node policy)* · #618 — author_user=-1 SQL error · #628 — strip hardcoded node IDs *(→ #4178)*
- #419 — scrub Recommended Reading for AdSense badwords · #452 — move other-users to a datastash job *(overlaps #4117)* · #525 — canonical URL for non-default Node types
- #500 — drop update_lastseen stored proc *(likely OBE — Request.pm does direct UPDATE)* · #501 — flaky ejection-count test
- #325 — unified error logging *(absorbs #781 full-SQL-on-DBI-error + #855 printErr→file)*
- **title validation** — #822 case-only-different e2node titles · #840 blank category titles (+ title-lookup #366)
- #933 — well-formed tables *(nested-table handling + homenode/draft coverage; #934 merged in)*
- #629 — getPage → controllers (not delegation) · #796 — extract notification/achievement code from shownewexp/showNewGP · #832 — use inDevEnvironment helper *(→ #4178)*
- **unused-dep prune** — #2575 Cache.pm · #2576 Date::Calc · #2578 Heap/Heap::Fibonacci · #2579 YAML *(verify-unused-then-remove sweep)*
- #2530 — drop VARS for Recent Node Notes *(→ setting→JSON)* · #2764 — (default) in Settings throws server error · #2770 — send-message-from-stylesheets busted · #2939 — investigate 'status' nodetypes (patch-system only) · #2972 — edev-nested-in-edev recursion hang (nodegroup guard)
- **encoding/data-scrub** — #2987 nodepack UTF-8 import · #3042 double-encoded â chars (+ #1107) *(verify post-utf8mb4; #3049 Webster thorn verified-healed & closed)*
- **broken-node data-integrity** — #3036 bad nodetype · #3043 parentless writeups excluded from New Writeups (+ #618, #1345)
- #2992 — export prefs as true/false *(→ setting→JSON)* · #3147 — move 'Intro to E2' out of E2Node type · #3271 — cron_clean_cbox 0E0 logging · #3330 — IQM recalc → datastash
- #3350 — New Logs should show hidden logs · #3390 — inconsistent parent on writeups in API · #3416 — usergroup notifies non-members *(#3887 merged in)* · #3604 — nodegroup-insert race (006_usergroup; ties retire-NodeBase) · #3621 — realign get_html_rules w/ approved tags · #3754 — migrate legacy notes to noter_user format
- **datastash jobs** — #3763 available rooms · #452 other-users · #3330 IQM recalc *(same 'move heavy work to datastash' pattern)*
- #3761 — refactor poll-creation out of maintenance ($query) · #3833 — refactor Duplicates-Found overloaded-$NODE hack · #3834 — rework random nodeshells · #3887 — group notifications too wide *(→ #3416)* · #3893 — search excerpts show HTML entities · #3916 — node-note notifications link to wrong URL
- #3948 — guest ilikeit broken · #3958 — HTML in user messages *(encoding)* · #3988 — lingering invalid_check notification code in DB · #3989 — evaluate whether the schema nodetype is needed *(cf #2939)* · #4009 — ilikeit notifications too wide *(notif-scope cluster w/ #3887/#3416)*
- #4114 — delete 4 vestigial htmlcode nodes · #4136 — add-to-collection adds parent e2node not the writeup · #4152 — Perl→React int fields serialize as strings *(truthy cluster w/ #4108)* · #4174 — XP-gain notification races itself (multiple oldexp consumers)
- #834 — unvotable writeups in writeups API · #844 — DB default collation still latin1_swedish_ci *(tables already utf8mb4)* · #856 — remove dead Everything::cleanLinks
- #877 — perlcritic silences cleanup · #897 — drop built-in-opcode special cases · #917 — cache perlcritic health check · #935 — routing to node ".."
- #971 — shared-draft title search regression · #1107 — Room Topics UTF-8 not importing to nodepack cleanly · #1243 — condense ENN/New Nodes/EKN/E2N into Writeups-by-Type
- #1283 — improve parselinks markup engine · #1345 — bad node type rows *(data cluster w/ #618)* · #1443 — remove delegated-maintenance code (now in controller)
- #1484 — Moose-import node_by_name/id to slim controllers · #1532 — username-uniqueness types → CONF *(→ #4178)* · #1550 — flaky usergroup tests *(cluster w/ #501)* · #1576 — Ed cool link null typing
- #1957 — public drafts not actually public · #1979 — Webster's writeups times out at ELB 30s *(perf)* · #1984 — regex recursion-limit blowup · #2155 — Recent Users oppressor→normal superdoc
- #2175 — legacy showchatter AJAX returns a Perl ref *(verify OBE vs React chatter)* · #2277 — new-user IP not reaching IP Hunter · #2351 — numeric-on-empty warning *(cluster w/ #268)* · #2462 — user param for homenode image *(homenode cluster)*
- #4184 — migrate setting.vars → JSON *(needs sqitch; DBIC-independent; absorbs #2992 boolean prefs)*

## epoch:social-login

- OAuth/social login feature → first `user_oauth` table → DBIC carve-out decision *(needs sqitch; see [orm-migration-plan.md](orm-migration-plan.md)). No issue yet._

## epoch:infra-cleanup

- #4182 — HTTP security posture (HttpOnly/Secure cookie, HSTS, headers, CSP) **(ships now, ungated)**
- #4146 — modernize dev build pipeline
- #4129 — remove mod_rewrite title hacks *(needs PSGI + #4163)*
- #4198 — audit + retire legacy opcode handlers (44 subs in Delegation/opcode.pm; overlaps delegation-removal/#897)
- #11 — normalize `user.imgsrc` path (drop `images/userimages/` prefix) *(homenode-images cluster)*
- #91 — rework `homenode_image_host` for the TLS/prod setup *(homenode-images cluster)*
- #116 — move robots.txt blocks → Apache UA blocking (`apache_blocks.json`)
- #119 — New Writeups Atom Feed → S3 + external cron (out of a fullpage)
- #28 — serve an `apple-touch-icon` (mobile bookmark + silences 404 noise)
- #165 — decide/configure gzip on API responses
- #325 — unified error logging (too many log files) *(PSGI changes logging anyway)*
- #566 — QA db-reload should create a node_forward type · #581 — podcast https links *(drop dead SWF/Flash player)*
- #1678 — migrate DB secret → SecretsManager *(deferred for cost: needs a paid VPC PrivateLink endpoint; S3 secrets-bucket works free. Revisit when rotation/audit is needed)*
- #2104 — make e2webmaster@everything2.com an actual inbox
- #2681 — pare down RDS partition size (100g over-provisioned) *(cost)*

> **homenode-images cluster** (#11 path, #91 host, + #13 captions in user-requests): handle as one coordinated effort — see "Robustness / clusters" below.

## Robustness / clusters

Many of the ancient issues are one-line 2012–2017 stubs that share a subject. Handle these as coordinated efforts, not scattershot, and let the enrichment pass (below) flesh them out:

- **homenode-images** — #11 (imgsrc path), #91 (`homenode_image_host` for TLS/prod), #13 (captions). One pass over how homenode images are stored, hosted, and rendered.
- **security/TLS** — #4182 (headers + cookie flags + PFS, absorbing #120/#1310/#2841/#141). Ships now, ungated.
- **encoding/UTF-8** — #4167 (entity-encoded titles), and verify-state of the recently-closed #3042/#4165 line; #113 (Cream of the Cool snippets) likely belongs here.

## Dedupe pass (planned — after tagging consolidation)

Once everything's tagged, sweep for duplicates/near-dups and merge. The tag pass is already surfacing pairs — e.g. #933/#934 (well-formed tables), #781/#855/#325 (logging), #836/#837 (numwriteups, already folded into #4173), #822/#840/#366 (title validation). Merge each cluster into a single canonical issue; close the rest pointing at it.

## Enrichment pass (planned — after tagging + dedupe)

Then a pass **per surviving issue**: enrich each terse old ticket with (a) current code state / file refs, (b) repro status today, (c) crisp acceptance criteria. This is what makes the 2012-era stubs actually actionable instead of "more robust" in name only. Tracks as its own activity, not part of the tag pass.

## epoch:user-requests

- #4183 — admin: view another user's nodeshells (backend half-wired)
- #13 — captions for homenode images *(homenode-images cluster)*
- #5 — a way to reset `$VARS{webloggables}` on yourself
- #20 — rebuild a "zeitgeist"/trending nodelet — **must source popularity from GSC/GA4 API, NOT node.hits** (hits tracking was killed for guest-write DB contention)
- #102 — nuking a writeup should just unpublish it (relates to #3415 removal + #4180 tombstoning)
- #1587 — random-node filter (add filters to Random Node)
- #2241 — multi-author writeups · #2242 — keywords for writeups · #2248 — notifications for Node Notes · #2516 — Content Report for space-prefixed node titles
- #2595 — let all editors (not just gods) edit usergroup descriptions
- #4015 — resurrect e2's help system (old displaytype=help)
- #4125 — restore softlink-overflow word cloud ('Chaos' button)
