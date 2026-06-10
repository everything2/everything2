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

    # 4. Capture STDOUT while running the chosen CGI-style handler. Capture RAW
    # BYTES, not :utf8: the app emits *bytes* -- UTF-8-encoded HTML, or (when the
    # client sends Accept-Encoding) a br/gzip/zstd-compressed BINARY body from
    # optimally_compress_page. A :utf8 layer corrupts that compressed binary, which
    # the browser then can't decode (net::ERR_CONTENT_DECODING_FAILED). Invisible to
    # curl-without-Accept-Encoding, fatal to every real browser page load.
    my $body = '';
    my $returned;
    open my $capture, '>:raw', \$body or die "capture open: $!";
    {
        local *STDOUT = $capture;
        # Re-assert the default output handle for THIS request. Under production
        # config, E2 can leave the process's *selected* filehandle
        # (select()/PL_defoutgv) pointing at a PRIOR request's captured STDOUT via
        # an unrestored select() deep in the stack (observed at the XS level). Once
        # that prior $capture is closed, every later plain print() on this preforked
        # Starman worker writes to a closed handle -> empty body + "print() on closed
        # filehandle $capture" -> 5xx, and stays poisoned until the worker recycles.
        # `local *STDOUT = $capture` only swaps the glob, NOT the selected handle, so
        # it can't fix a leaked selection on its own. Selecting STDOUT (now aliased to
        # this request's $capture) makes each request immune. See issue #4237.
        select STDOUT;
        my $ok = eval {
            if ($is_api) {
                Everything::initEverything();
                $returned = $APIr->dispatcher;
            }
            else {
                mod_perlInit();
            }
            1;
        };
        unless ($ok) {
            my $err = $@ || 'unknown error';
            close $capture;
            return [ 500, [ 'Content-Type' => 'text/plain' ],
                     [ "PSGI wrapper caught a die from " .
                       ($is_api ? 'APIRouter' : 'mod_perlInit') . ":\n$err" ] ];
        }
    }
    close $capture;

    # Return-based fast path: an API handler that returned an Everything::Response is
    # finalized directly -- it never went through the STDOUT capture, so it is immune
    # to the #4237 capture-poisoning class. The page path (mod_perlInit) prints into
    # the capture and leaves $returned unset, so it falls through to the capture
    # parser below. Dual-mode; the capture is deleted last, once nothing prints.
    # See docs/api-driven-architecture.md.
    if ( $APIr->is_response($returned) ) {
        return $returned->finalize;
    }

    return _cgi_output_to_psgi($body);
};

# CGI response (Header: val CRLF ... CRLF CRLF body) -> PSGI [status, headers, body].
sub _cgi_output_to_psgi {
    my ($raw) = @_;

    unless ( $raw =~ /\r?\n\r?\n/ ) {
        return [ 200, [ 'Content-Type' => 'text/html; charset=utf-8' ], [ $raw ] ];
    }

    my ( $head, $body ) = split /\r?\n\r?\n/, $raw, 2;
    $body //= '';

    my $status = 200;
    my @headers;
    my $have_ct = 0;
    for my $line ( split /\r?\n/, $head ) {
        my ( $k, $v ) = split /:\s*/, $line, 2;
        next unless defined $v;
        if ( lc $k eq 'status' ) {
            ($status) = $v =~ /(\d{3})/;
            $status ||= 200;
        }
        else {
            $have_ct = 1 if lc $k eq 'content-type';
            push @headers, $k, $v;     # multiple Set-Cookie lines each push a pair
        }
    }
    push @headers, 'Content-Type', 'text/html; charset=utf-8' unless $have_ct;

    return [ $status, \@headers, [ $body ] ];
}

# Serve the file-backed static assets (/css, /react, /images, /static, favicon)
# so Starman is self-sufficient when run standalone. In the real deployment Apache
# serves these and proxies only dynamic requests here -- belt-and-suspenders.
builder {
    enable 'Static',
        path => qr{^/(?:css|react|images|static|js|sound|fonts)/|^/favicon\.ico$},
        root => '/var/everything/www/';
    $app;
};
