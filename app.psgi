# app.psgi -- PSGI wrapper SPIKE for Everything2 (PSGI migration, plan step 1).
#
# E2 is CGI-style. Two entry points, both of which read %ENV + STDIN and PRINT a
# CGI response (headers + body) to STDOUT:
#   * pages : www/index.pl  -> Everything::HTML::mod_perlInit()
#   * api   : www/api/index.pl -> initEverything + Everything::APIRouter->dispatcher
# Apache routes /api/* to the second and everything else to the first; this
# wrapper reproduces that split. The bridge ($env -> %ENV, psgi.input -> STDIN,
# capture STDOUT, parse to a PSGI triple) is identical for both -- no ecore/
# changes. SPIKE: validated under plackup + Starman; not production-hardened.
#
#   /var/libraries/bin/starman --workers 2 --listen :5000 app.psgi
#
use strict;
use warnings;
use lib '/var/everything/ecore';
use Everything;
use Everything::HTML;
use Everything::APIRouter;
use Everything::HealthCheck;
use Plack::Builder;

# Preload once per worker (mirrors mod_perl's persistent interpreter). The API
# router builds its controller table at construction -- do it at load, not per
# request.
my $APIr = Everything::APIRouter->new;

# The PSGI health-check app (replaces the mod_perl www/health.pl). Built once
# per worker. Answers /health + /health.pl below, before any request setup.
my $health_app = Everything::HealthCheck->to_app;

# Per-worker flag: has this worker loaded the core-node hydration bundle yet? The
# lexical is COW-copied at fork, so each worker gets its own (undef) and hydrates
# exactly once, on its first real request. This is the ONLY place hydration is
# triggered -- it is a web-request optimization, so scoping it to the web boot path
# keeps cron/batch scripts and the test suite (which never run app.psgi) on their
# lean caches, with no env flag or config knob to misconfigure. See #4423/#4439.
my $hydrated;

my $app = sub {
    my $env = shift;

    # Health check, answered by Everything::HealthCheck directly from the PSGI
    # layer (before any request setup, so basic liveness stays cheap and DB-
    # independent). This is the PSGI rewrite of the old mod_perl www/health.pl,
    # which is Apache-bound and can't run under Starman. A green /health proves
    # the real serving path -- Apache -> Starman -> Perl -- is up: if Starman is
    # down, Apache's proxy returns 503 and ECS recycles the task. ?detailed=1 adds
    # system/memory; ?db=1 adds a framework-free DB probe (503 if unhealthy).
    my $health_path = ( $env->{REQUEST_URI} // '' ) =~ s/\?.*//r;
    if ( $health_path eq '/health' || $health_path eq '/health.pl' ) {
        return $health_app->($env);
    }

    # (Historical: a CGI::initialize_globals() call lived here to reset CGI.pm's
    # package globals per request and avoid cross-request bleed -- mod_perl did
    # that reset, a bare PSGI server doesn't. It's gone now: CGI.pm is no longer
    # in the request path. Everything::Request::PlackQuery is built fresh from
    # this $env on every request, so there is no shared parsed-query global to
    # bleed in the first place.)

    # 1. PSGI env -> %ENV (CGI-named request vars + HTTP_* headers).
    local %ENV = %ENV;
    for my $k ( keys %$env ) {
        next if $k =~ /^psgi/;
        next if ref $env->{$k};
        $ENV{$k} = $env->{$k};
    }
    $ENV{TZ} = '+0000';
    # NB: Accept-Encoding is deliberately NOT stripped here -- the app still needs
    # it so asset_uri() picks the right pre-compressed S3 CSS/JS variant. Response
    # *body* compression is disabled app-side under PSGI via compress_response_body
    # (Apache compresses the proxied body at the edge instead).

    # CGI-app contract reconciliation. E2's Everything::Request::_build_cgi gates
    # `new CGI` (read the live request) vs `new CGI(\*STDIN)` (read from a handle)
    # on SCRIPT_NAME being truthy, and the API dispatcher routes on
    # url(-absolute=>1) which returns SCRIPT_NAME. Apache sets SCRIPT_NAME to the
    # full request path; PSGI leaves it empty with the path in PATH_INFO. Remap to
    # the Apache shape (full path in SCRIPT_NAME, empty PATH_INFO) so both the CGI
    # construction AND the /api routing work.
    my $full_path = ( defined $env->{PATH_INFO} && length $env->{PATH_INFO} )
        ? $env->{PATH_INFO}
        : ( $env->{REQUEST_URI} // '/' ) =~ s/\?.*//r;
    $ENV{SCRIPT_NAME} = $full_path || '/';
    $ENV{PATH_INFO}   = '';

    # 2. STDIN <- psgi.input (POST/PUT/PATCH bodies for CGI.pm).
    local *STDIN = $env->{'psgi.input'} if $env->{'psgi.input'};

    # 2b. Thread the PSGI env to Everything::Request so its Plack::Request backing
    # (Everything::Request::PlackQuery) parses the request. Thread a COPY with the
    # same SCRIPT_NAME/PATH_INFO remap applied to %ENV just above, so Plack's
    # script_name/path/url match what CGI read from %ENV (full path in
    # SCRIPT_NAME, empty PATH_INFO). Localized per request. See
    # docs/plack-request-migration.md.
    local $Everything::Request::PSGI_ENV = {
        %$env,
        SCRIPT_NAME => $ENV{SCRIPT_NAME},
        PATH_INFO   => $ENV{PATH_INFO},
    };

    # 3. Pick the handler the way Apache does: /api/* -> dispatcher, else pages.
    my $path = $env->{PATH_INFO};
    $path = $env->{REQUEST_URI} // '/' unless defined $path && length $path;
    my $is_api = $path =~ m{^/api/};

    # 4. Run the chosen CGI-style handler. Both paths are now RETURN-BASED (#4483): the
    # API dispatcher and mod_perlInit each return an Everything::Response that we finalize
    # to a PSGI triple directly. The old STDOUT-capture-and-parse-back machinery -- and
    # with it the #4237 select-STDOUT re-assert dance that guarded a leaked capture
    # selection -- is gone: nothing in the request path prints to STDOUT anymore (proven
    # by the 1c straggler sweep across the full e2e suite + every page type). Removing the
    # per-request capture handle also structurally eliminates the #4237 capture-poisoning
    # class -- there is no capture to leave selected or to close out from under a later
    # print. See docs/step1-return-based-controllers.md.
    my $returned;
    my $ok = eval {
        # First real request on this worker: ensure $DB exists, then eagerly load the
        # core-node hydration bundle into this worker's cache (once). Inside the request
        # eval so a load failure degrades gracefully rather than poisoning the worker;
        # loadHydrationCache is itself best-effort.
        unless ($hydrated) {
            Everything::initEverything();
            $Everything::DB->{cache}->loadHydrationCache;
            $hydrated = 1;
        }
        if ($is_api) {
            Everything::initEverything();
            $returned = $APIr->dispatcher;
        }
        else {
            $returned = mod_perlInit();
        }
        1;
    };
    unless ($ok) {
        # A die anywhere in the render unwinds through HTML::handle_errors (which
        # re-throws while inside this eval, $^S true) to here. Build a fresh 500 -- the
        # error response never depended on captured bytes.
        my $err = $@ || 'unknown error';
        return [ 500, [ 'Content-Type' => 'text/plain' ],
                 [ "PSGI wrapper caught a die from " .
                   ($is_api ? 'APIRouter' : 'mod_perlInit') . ":\n$err" ] ];
    }

    # Both the API and page paths return an Everything::Response; finalize it.
    if ( $APIr->is_response($returned) ) {
        return $returned->finalize;
    }

    # A controller that neither emitted a Response nor died is a bug (post-1b every page
    # path stashes one via Router::output or a mod_perlInit short-circuit). Fail loud
    # rather than silently serve an empty 200.
    warn "app.psgi: no Everything::Response produced for path=$path (is_api=$is_api)\n";
    return [ 500, [ 'Content-Type' => 'text/plain' ], [ 'No response produced' ] ];
};

# Serve the file-backed static assets (/css, /react, /images, /static, favicon)
# so Starman is self-sufficient when run standalone. In the real deployment Apache
# serves these and proxies only dynamic requests here -- belt-and-suspenders.
builder {
    enable 'Static',
        path => qr{^/(?:css|react|images|static|js|sound|fonts)/|^/favicon\.ico$},
        root => '/var/everything/www/';
    $app;
};
