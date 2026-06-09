# Plack::Request migration — surface audit & approach

**Status:** design / discovery (2026-06-08, rev 2). Successor to the PSGI migration: PSGI gave
us the *server*; this replaces the CGI.pm *request layer* with Plack::Request while keeping
`Everything::Request` as the auth-bearing façade.

**Principle:** composition, not inheritance — `Everything::Request` (Moose) *wraps* a
`Plack::Request` (a blessed hashref over the PSGI env), rather than subclassing it (avoids
the Moose / non-Moose friction). The new way becomes the only way by making the single seam
— `Everything::Request->cgi` — Plack-backed.

**Working principle (rev 2):** declare a clean model and migrate each meaningful site *with
test coverage* — do **not** transparently emulate CGI's messy surface. A transparent shim
migrates the *backing* without verifying any call *site*; with spotty coverage that hides
regressions in untested paths and enshrines the mutation mess as a permanent "compat" layer.

---

## The seam (the leverage point)

- `ecore/Everything/Request.pm:11` — `has 'cgi' => (isa => "CGI", builder => "_build_cgi",
  handles => [param, header, cookie, url, request_method, path_info, script_name])`
- `_build_cgi` (Request.pm:94/96) — `new CGI` / `new CGI(\*STDIN)`.
- `Everything::HTML`'s global `$query = $REQUEST->cgi` — so **`$query` *is* the cgi object**.

One object backs three caller populations:
| Caller form | count | nature |
|---|---|---|
| façade `$REQUEST->param` | 71 | clean — already abstracted |
| global `$query->...` | 454 `param` + tail | reaches the raw object |
| direct `$REQUEST->cgi->...` | 174 | bypasses the façade |

## Surface area (quantified)

| Usage | count | difficulty | target |
|---|---|---|---|
| `param` (overwhelmingly reads) | ~525 | **easy** (mechanical) | `Plack::Request->parameters` |
| `$REQUEST->cgi->X` (façade bypass) | 174 | medium | migrate to façade |
| param **mutation** (`delete`/`delete_all`/`param(k,v)`) | ~10 | **hard** | immutable model (below) |
| **response-gen** via request (`header`/`redirect`/`print`) | 8 | **hard** | Plack::Response (response epoch) |
| CGI **form-helpers** (`hidden`/`submit`/`checkbox`/`textfield`/`start_form`) | ~10 | **hard** | real HTML / React (likely dead) |
| `Vars` | 3 | medium | `Hash::MultiValue` |
| raw body: `$REQUEST->POSTDATA` / `JSON_POSTDATA` | 21 / 89 | medium | `$req->content` / `body_parameters` |
| direct `new CGI` | 4 (2 are the seam) | bounded | see below |

**Coupling is concentrated, not spread:** `API/messages.pm` (14), `Request.pm` (5),
`API/chatter.pm` (4), `client_errors`/`category` (3 each); everything else 0–1.

## Why a backing-swap alone isn't transparent (and why we don't want it to be)

The 174 `->cgi->X` + 454 `$query->X` callers use CGI methods (`param`, `Vars`, mutation,
form-helpers) whose semantics differ from Plack::Request — so we can't just flip
`isa => "Plack::Request"`. But we also **won't emulate** the messy surface transparently:
that would migrate the backing without verifying a single call site, hide regressions in
untested code, and keep the mutable-param mess alive as "compat" forever. Instead: a clean
immutable model + a parity harness for the read surface + deliberate per-site migration for
the risky surface.

## Clean model (the declared target)

**Request params are immutable** — read-only, backed by `Plack::Request->parameters`. The ~10
sites that "mutate" params today aren't mutating a request; they're three patterns wearing
CGI's clothes, each re-expressed cleanly:
- `handleUserRequest` setting `node`/`type` = routing **derivation** (resolve URL → node) →
  produce a resolved descriptor; leave the query alone.
- redirect path deleting `lastnode_id`/`op` = build the canonical URL from a **filtered copy**.
- XSRF `delete_all` = the controller **ignores** the params; nothing to mutate.

Each site migrates deliberately, with its own test. No mutable-param emulation.

## Test coverage strategy (what makes "ensure coverage" tractable)

Coverage is spotty, so we don't chase per-site tests for the ~525 reads (param-read is
param-read; the risk is the *decoding layer*, not the call site). Two-pronged:

1. **Request-layer parity harness — covers all 525 reads as a layer.** Replay a corpus of real
   request shapes through CGI *and* Plack::Request and assert identical results:
   - multi-value params, empty/duplicate keys
   - UTF-8 titles + the `&`-in-title cases (#4060), `;` vs `&` separators
   - cookies, headers-in, `request_method`, POST bodies (urlencoded + JSON — the
     `decode_utf8`-before-`decode_json` byte gotcha)
   One strong test pins the decoding risk for the whole read surface; the 88-test e2e suite is
   the integration backstop.
2. **Per-site characterization tests for the ~30–40 *risky* sites** (mutation, `Vars`,
   response-gen, form-helpers, `new CGI`). These carry real semantic content and concentrate
   the risk — so each gets its own test as it migrates to the clean model. This is the surface
   where your "declare a clean model, work each site with coverage" approach is exactly right.

## Optional migration scaffold (strict, throwaway — not a crutch)

If we keep `Everything::Request->cgi` as a transitional bridge, it is **read-only and strict**:
`param`(read)/`cookie`/`url`/`request_method`/`http`/etc. delegate to Plack::Request, while
**`param(k,v)`/`delete`/`Vars`/`header`/`redirect`/`print`/form-helpers THROW loudly.** That
makes a silent "it-still-works-through-the-shim" impossible and forces every risky site into
deliberate migration-with-test. The scaffold is built to be deleted (final phase).
*Alternative:* skip the scaffold and migrate the reads mechanically behind the parity harness
(migrate-then-flip). Taste call — see open questions.

## CGI → Plack mapping

| CGI | Plack | notes |
|---|---|---|
| `$q->param('x')` | `$req->param('x')` / `parameters->{x}` | read (mechanical) |
| `$q->param('x',$v)` / `delete` / `delete_all` | **immutable** — derive a value / filtered copy / routing state | per-site migration + test |
| `$q->Vars` | `$req->parameters` (Hash::MultiValue) | flatten |
| `$q->cookie('x')` | `$req->cookies->{x}` | |
| `$q->url(-absolute=>1)` | `$req->path` / `$req->uri` | (app.psgi already remaps SCRIPT_NAME) |
| `$q->request_method` | `$req->method` | |
| `$q->http('X-...')` | `$req->headers->header('X-...')` | |
| `$q->remote_addr` | `$req->address` | NB getIp already prefers XFF |
| `$q->header(...)` | `Plack::Response->new(...)` | **response epoch** |
| `$q->redirect(...)` | `$res->redirect(...)` | **response epoch** (the #4237 303 site) |
| `$q->print(...)` | `$res->body(...)` | **response epoch** (retires the STDOUT capture) |
| `$q->hidden/submit/checkbox/...` | real HTML / React | presentation; verify dead |

## Hard parts (detail)

1. **Param mutation (~10) — migrate to the immutable model, no emulation.** Per the clean model:
   `node`/`type` derivation → resolved descriptor; redirect param-strip → filtered copy; XSRF
   `delete_all` → controller ignores. Each site deliberate + tested. Touches `handleUserRequest`
   — its own mini-epoch.
2. **Response-via-request (8).** The `header`/`redirect`/`print` sites are the *request* object
   doing *response* work — this **is** the STDOUT-capture coupling. Migrate as part of the
   Plack::Response / return-based-response epoch; co-sequence. The 303 redirect at `HTML.pm:887`
   lives here (and was the #4237 source).
3. **CGI form-helpers (~10).** `hidden`/`submit`/`checkbox`/`textfield`/`start_form` — legacy
   presentation in htmlcode (per current read, "mostly dead"). Verify which are live, replace
   those, delete the rest.
4. **`new CGI` sites (4):** `HTML.pm:857` (redirect clone — response epoch), `www/health.pl:42`
   (**verify DEAD** — app.psgi answers `/health` directly now), `Request.pm:94/96` (the seam).
5. **Raw body (`POSTDATA`/`JSON_POSTDATA`, 110 uses).** Already abstracted behind `$REQUEST`
   (the `_raw_stdin_cache`), so lower-risk — map to `$req->content` / `body_parameters`. Covered
   by the parity harness's POST-body corpus.

## Sequencing

- **Phase 0** — delete confirmed-dead CGI consumers (`health.pl`?, dead htmlcode form-helpers)
  to shrink the surface before touching the seam.
- **Phase 1** — build the **parity harness** (CGI vs Plack::Request decoding corpus). Coverage
  for the read surface as a *layer*, before flipping anything.
- **Phase 2** — declare the immutable model; migrate the ~30–40 **risky sites** one at a time
  (mutation, `Vars`, form-helpers), each with its own test.
- **Phase 3** — flip the backing (`_build_cgi` → Plack::Request, behind the strict read-only
  scaffold *or* mechanically). Parity harness + e2e are the backstop. **CGI.pm out of the live
  request path** — the headline win.
- **Phase 4 (response epoch)** — move `header`/`redirect`/`print` to Plack::Response /
  return-based responses; **retires the STDOUT capture** as a consequence (not a bugfix).
- **Phase 5** — delete the scaffold; pure Plack-backed `Everything::Request`; remove `use CGI`.

## Open questions (to refine)

- **Scaffold or no scaffold:** strict read-only bridge (flip-then-shrink) vs. mechanical read
  migration behind the parity harness (migrate-then-flip). Appetite for a transitional object.
- **`Everything::Request->cgi` as a public name:** 174 callers reach `->cgi`. Keep the accessor
  (returning the scaffold / Plack::Request) as the target, or rename to `->req` and deprecate
  `->cgi` so the migration is *visible* at each call site?
- **`handleUserRequest` routing rework:** re-expressing the node/type derivation as a resolved
  descriptor is the mutation epoch's center of gravity — scope it as its own mini-design.
- **CGI param-decoding parity edge cases:** the parity harness must enumerate the real ones
  (#4060 `&`-in-title, the `;`/`&` separator, UTF-8, the JSON byte gotcha) — build that corpus
  from known historical bugs, not from scratch.

---

## Appendix A — transitional `Everything::Request` + caller hierarchy

`Everything::Request` is the whole migration in miniature: clean reads (`param`, `cookie`),
`->cgi` self-leaks (`make_login_cookie`, `truncated_params`, the `checkToken` arg), and
response-gen hiding inside the request object (`print $self->header({-cookie=>…})`, the
`cookie(-name=>…)` *generation* in `make_login_cookie`).

### Transitional object

```perl
package Everything::Request;
use Moose; use namespace::autoclean;
use Plack::Request;
# `use CGI` stays only until the shim is deleted (final phase)
with 'Everything::Globals';

# --- NEW backing: the real Plack::Request over the PSGI env ---------------------
has 'req' => (
  is => 'ro', isa => 'Plack::Request', lazy => 1, builder => '_build_req',
  handles => {                 # the clean READ façade, re-pointed to Plack
    param           => 'param',          # READ ONLY (a 2-arg set lives nowhere)
    cookie_value    => 'cookie',         # read a cookie value (was overloaded with gen)
    request_method  => 'method',         # keep legacy name
    method          => 'method',
    path_info       => 'path_info',
    address         => 'address',
    headers         => 'headers',
    content         => 'content',
    body_parameters => 'body_parameters',
  },
);
sub _build_req { Plack::Request->new($_[0]->psgi_env) }

sub op     { $_[0]->param('op') // '' }   # replaces the build-time `param("op","")` mutation
sub params { $_[0]->req->parameters }     # immutable Hash::MultiValue

# --- identity/auth, UNCHANGED (E2's value on top of Plack) ----------------------
has 'user' => (lazy=>1, builder=>"_build_user", isa=>"Everything::Node::user", is=>"rw",
  handles => ["is_guest","is_admin","is_developer","is_chanop","is_clientdev","is_editor","VARS"]);
has 'node' => (is=>"rw", isa=>"Everything::Node");
has 'NODE' => (is=>"rw", isa=>"HashRef");

# --- TRANSITIONAL: the 174 `$REQUEST->cgi->X` callers, behind a STRICT shim ------
has 'cgi' => (is=>'ro', lazy=>1, builder=>'_build_cgi_shim');
sub _build_cgi_shim { Everything::Request::CGIShim->new(req => $_[0]->req) }

__PACKAGE__->meta->make_immutable;
```

**Prerequisite (the actual first commit):** thread the PSGI `$env` to `Everything::Request`.
Today app.psgi builds `%ENV` and `$REQUEST` never sees `$env`; `Plack::Request->new` needs it.
app.psgi stashes it (`local $Everything::Request::PSGI_ENV = $env`, or pass into `->new`) and
`psgi_env` reads it.

### Strict shim (reads delegate; risky ops throw → worklist generator)

```perl
package Everything::Request::CGIShim;
use Moose; use namespace::autoclean; use Carp qw(croak);
has 'req' => (is=>'ro', isa=>'Plack::Request', required=>1);

# READS -> delegate (identical to CGI; covered by the parity harness)
sub param { my $s=shift; croak "param(set): immutable -- derive/route" if @_>1; $s->req->param(@_) }
sub multi_param    { $_[0]->req->parameters->get_all($_[1]) }
sub request_method { $_[0]->req->method }
sub http           { $_[0]->req->headers->header($_[1]) }
sub remote_addr    { $_[0]->req->address }
sub cookie { my $s=shift; croak "cookie(gen): Set-Cookie is response work" if @_>1; $s->req->cookies->{$_[0]} }

# MUTATION -> throw (immutable model)
sub delete     { croak "param delete: filtered copy / routing state, not mutation" }
sub delete_all { croak "delete_all: controller ignores params, not mutate" }
sub Vars       { croak "Vars: use \$REQUEST->params (immutable Hash::MultiValue)" }

# RESPONSE-GEN -> throw (response epoch / Everything::Response)
sub header   { croak "header(): response work -- build an Everything::Response" }
sub redirect { croak "redirect(): response work -- \$res->redirect" }
sub print    { croak "print(): response work -- \$res->body" }

# CGI FORM-HELPERS -> throw (presentation)
BEGIN { for my $h (qw(hidden submit checkbox textfield start_form)) {
  no strict 'refs'; *{$h} = sub { croak "$h(): CGI form-helper -- emit HTML/React" }; }}
__PACKAGE__->meta->make_immutable;
```

The shim can't become a silent crutch: once the backing is flipped, every un-migrated
mutation/response/form site throws with a message pointing where to go — the ordering enforces
itself (can't flip until the risky sites are migrated).

### Clean caller hierarchy (end state — response work leaves the request)

```
$REQUEST  (read-only request facts, Plack-backed)
  ->param('node_id') / ->params / ->cookie_value('userpass')
  ->method / ->headers->header('X-...') / ->address
  ->json_body / ->body                # replaces POSTDATA / JSON_POSTDATA

$REQUEST->user  (identity/auth -- E2's layer on top)
  ->is_guest / ->VARS / ->is_editor / ...

$RESPONSE  (NEW -- response work that used to live on the request)  -- see Appendix B
  ->status / ->set_cookie(...) / ->redirect(...) / ->body / ->finalize
```

| today (request doing response work) | clean |
|---|---|
| `print $self->header({-cookie => $self->make_login_cookie(...)})` | `$res->set_cookie(userpass => {...})`; no print |
| `make_login_cookie` → `$self->cookie(-name=>…)` | a plain hashref the response serializes |
| `$self->cgi->param('expires')` | `$self->param('expires')` (façade read) |
| `checkToken($user->NODEDATA, $self->cgi)` | pass `$self` (or the param), not raw cgi |
| `truncated_params` via `$self->cgi->multi_param` | `$self->params` |

---

## Appendix B — the `$RESPONSE` object (response epoch) — sketch for discussion

Composition mirror of the request side: `Everything::Response` wraps `Plack::Response`. This is
what controllers **return** instead of printing — and returning one makes a handler **immune to
the STDOUT-capture bug class (#4237)**, because it never touches the capture.

```perl
package Everything::Response;
use Moose; use namespace::autoclean;
use Plack::Response;

has 'res' => (is=>'ro', isa=>'Plack::Response', lazy=>1,
  default => sub { Plack::Response->new(200) },
  handles => {
    status       => 'status',       # get/set
    content_type => 'content_type',
    header       => 'header',        # set a response header
    redirect     => 'redirect',      # $res->redirect($url, 303)  <- the #4237 303 site
    body         => 'body',
    finalize     => 'finalize',      # -> PSGI triple [status, \@headers, \@body]
  });

# Set-Cookie -- replaces CGI cookie(-name=>...) generation + the print-the-header pattern
sub set_cookie {            # $spec: { value, expires, path, samesite, httponly, secure }
  my ($self, $name, $spec) = @_;
  $self->res->cookies->{$name} = $spec;   # Plack::Response::finalize emits Set-Cookie
  return $self;
}

# convenience builders
sub json {                  # the API path
  my ($self, $data, $status) = @_;
  $self->res->status($status // 200);
  $self->res->content_type('application/json; charset=utf-8');
  $self->res->body($self->JSON->encode($data));
  return $self;
}
sub html {                  # the page path
  my ($self, $markup, $status) = @_;
  $self->res->status($status // 200);
  $self->res->content_type('text/html; charset=utf-8');
  $self->res->body($markup);
  return $self;
}
__PACKAGE__->meta->make_immutable;
```

### Framework integration — `Router::output` returns instead of prints

```perl
# Everything::Router::output, after  ($output = [$status, $data, $headers] from a controller)
sub output {
  my ($self, $REQUEST, $output) = @_;
  my $res = Everything::Response->new;
  $res->status($output->[0] // 200);
  my $h = $output->[2] || {};
  $res->set_cookie($h->{cookie}{name} => $h->{cookie}) if $h->{cookie};   # was the leaky print
  ($h->{type}//'') eq 'application/json'
    ? $res->json($output->[1], $output->[0])
    : $res->html($self->APP->optimally_compress_page($output->[1] // ''), $output->[0]);
  return $res;                 # <- NOT print
}
```

### Transitional dual-mode in app.psgi (this is what makes the epoch incremental)

Keep the STDOUT capture as a **fallback** while migrating; a handler that returns an
`Everything::Response` bypasses it entirely. The capture (and `_cgi_output_to_psgi`) is deleted
only when nothing prints anymore.

```perl
my $body = ''; open my $capture, '>:raw', \$body;
my $resp;
{ local *STDOUT = $capture; select STDOUT;
  my $ok = eval { $resp = $is_api ? $APIr->dispatcher : mod_perlInit(); 1 };
  unless ($ok) { close $capture; return [500, ['Content-Type'=>'text/plain'], ["$@"]] }
}
close $capture;
return $resp->finalize if blessed($resp) && $resp->isa('Everything::Response');  # NEW path
return _cgi_output_to_psgi($body);                                              # legacy capture
```

So the API path (already return-shaped) goes first → immediately immune to #4237; the page path
follows as its print sites convert (coupled to the htmlcode cleanup); the capture is the last
thing deleted. This is why the response epoch is sequenced **after** the request migration and
**alongside** the dead-htmlcode burn-down.

### Open questions for the response shape
- **Return contract:** do controllers return `Everything::Response`, or keep returning
  `[status, data, headers]` and let `Router::output` build the response? (Latter is less churn
  at call sites; former is cleaner long-term.)
- **Cookie spec shape:** standardize the `set_cookie` hashref (value/expires/path/samesite/
  httponly/secure) so it's the one place cookie policy lives (today it's scattered in
  `make_login_cookie`, `opLogout`, etc.).
- **Streaming/large bodies:** Plack::Response buffers; if any endpoint needs streaming
  (sitemaps? exports?), note where a PSGI streaming response is needed instead.

---

## Appendix C — `PageState` extraction (the e2 blob, out of the god module)

`Application.pm::buildNodeInfoStructure` is **947 lines inside an 8,761-line god module** — it
builds the `e2` JSON blob every controller mounts the React app with. Extracting it is the
high-value refactor adjacent to the controllers (the controller *construct* is sound and stays).

### The finding that shapes the design: chrome vs content

The blob is ~45 top-level keys. Only ~9 are **node-specific** (`node`, `nodetype`,
`contentData`, `nodeCategories`, `currentNodeId/Title`, `sourceMap`); the other ~35 are
**page-independent per-user chrome** — every nodelet (`chatterbox`, `epicenter`, `newWriteups`,
`news`, `randomNodes`, `statistics`, `recentNodes`, `masterControl`, …), identity, messages,
system config. That chrome is rebuilt on **every** page load for a user. So `PageState` isn't
just "extract 947 lines" — it **splits chrome from content**, which is the **page-state API
seam**: chrome is page-independent and cacheable (a `/api/pagestate` returns exactly that),
content is per-node. That split later unblocks React-owned routing without re-fetching the
whole world per navigation.

### The class

```perl
package Everything::PageState;
use Moose; use namespace::autoclean;
with 'Everything::Globals';

# named inputs replace the positional god-signature ($NODE,$USER,$VARS,$query,$REQUEST)
has 'request' => (is=>'ro', isa=>'Everything::Request', required=>1, handles=>['user']);
has 'node'    => (is=>'ro', isa=>'Maybe[Everything::Node]');     # content node (optional)

# 1) CHROME: page-independent per-user shell (cacheable; shape of /api/pagestate)
has 'chrome'  => (is=>'ro', isa=>'HashRef', lazy=>1, builder=>'_build_chrome');
# 2) CONTENT: per-node, set by the controller
has 'content' => (is=>'rw', isa=>'HashRef', default=>sub { {} });

sub _build_chrome {
  my $self = shift; my $u = $self->user;
  return {
    user          => $self->_user_section,
    guest         => $u->is_guest ? 1 : 0,
    display_prefs => $self->APP->display_preferences($u->VARS),
    nodelets      => $self->_nodelets,         # built on demand (below)
    messages      => $self->_messages_section, # messagesData/notificationsData/usergroupData
    system        => $self->_system_section,   # assets_location/use_local_assets/lastCommit/recaptcha
  };
}

sub e2 {                                        # what React mounts with = chrome + content + identity
  my $self = shift; my $n = $self->node;
  return {
    %{ $self->chrome },
    contentData   => $self->content,
    reactPageMode => \1,
    ($n ? (node_id=>$n->node_id, title=>$n->title,
           currentNodeId=>$n->node_id, currentNodeTitle=>$n->title) : ()),
  };
}
__PACKAGE__->meta->make_immutable;
```

### Sub-thread: nodelets become a built-on-demand collection

Today the god-method builds *all* nodelet data unconditionally. PageState builds only what the
user has configured (free perf win) and gives each nodelet a home:

```perl
sub _nodelets {
  my $self = shift; my %out;
  for my $key (@{ $self->_configured_nodelet_keys }) {     # from VARS->{nodelets}
    my $builder = $self->APP->nodelet_builder($key) or next;
    $out{$key} = $builder->data($self);                    # each nodelet owns its data build
  }
  return \%out;
}
```

`chatterbox`/`newWriteups`/`epicenter`/… each become a small unit with a `data($state)` method
— testable in isolation, and chatterbox data stops being built for users who don't show it.

### Integration — controller + transitional delegate

```perl
# a controller displaytype, after:
sub display {
  my ($self, $REQUEST, $node) = @_;
  my $state = Everything::PageState->new(request=>$REQUEST, node=>$node);
  $state->content({ type=>'default_display', nodeId=>$node->node_id, nodeTitle=>$node->title });
  return Everything::Response->new->html(
    $self->layout('/pages/react_page', e2=>$state->e2, REQUEST=>$REQUEST, node=>$node));
}

# Application.pm during extraction -- the 947-line method becomes a 1-line delegate, so every
# existing caller keeps working while the body moves into PageState section by section:
sub buildNodeInfoStructure {
  my ($this, $NODE, $USER, $VARS, $query, $REQUEST) = @_;
  return Everything::PageState->new(request=>$REQUEST, node=>$REQUEST->node)->e2;
}
```

### Wins
- **Testable as a layer** — construct with a fixture request+node, assert `chrome`,
  `_user_section`, each nodelet's `data`. This **is** the controller test net we lack today
  (0 unit tests on the construct), and it covers the e2-blob risk in one place. Pairs with the
  **parametrized controller harness** (run every controller's `display` against a representative
  node, assert 200 + well-formed `e2`).
- **Decomposes the god module** — 947 lines leave `Application.pm` (8.7K → ~7.8K) into a cohesive
  class with named sections, extracted incrementally behind the delegate.
- **Page-state API seam** — `chrome` is the cacheable, page-independent contract; content is
  per-node. The normalization the React-routing epoch needs.
- **Pairs with `Everything::Response`** — the response carries `$state->e2`; the controller
  shrinks to "build content, return a response."

### Sequencing (slots into the main plan, between the controller harness and the response contract)
1. Parametrized **controller harness** (the net).
2. Introduce `Everything::PageState`; make `buildNodeInfoStructure` a **delegate**; move sections
   in one at a time (identity → system → messages → nodelets), each with a section test.
3. Split out the **nodelet-builder collection** (own sub-thread); switch to build-on-demand.
4. Migrate controllers to construct `PageState` directly + return `Everything::Response`; delete
   the `buildNodeInfoStructure` delegate.
5. Expose `chrome` as `/api/pagestate` when the React-routing epoch wants it.

### Open questions
- **Cache key for `chrome`:** per-user, but invalidated by what? (new message, nodelet config
  change, level-up …) — defines whether `/api/pagestate` is cacheable in practice.
- **`layout`/React shell** still takes the whole `e2`; once chrome/content are split, does the
  shell mount with both, or fetch chrome separately? (Ties to the routing epoch.)
- **Nodelet builder registry:** reuse the existing `plugin_table`/PAGE_TABLE machinery, or a new
  `nodelet` plugin type? (42 controllers already use `plugin_table("page")`.)
