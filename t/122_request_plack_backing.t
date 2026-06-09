#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions RequireExtendedFormatting RequireLineBoundaryMatching RequireDotMatchAnything)
## no critic (ValuesAndExpressions ProhibitInterpolationOfLiterals ProhibitMagicNumbers)

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;
use Everything::Request;

initEverything('development-docker');

ok($DB, "Database connection established");

# Build a small PSGI env helper (empty body unless given).
sub make_env {
    my (%over) = @_;
    open(my $in, '<', \(my $body = $over{__body} // '')) or die $!;
    delete $over{__body};
    return {
        REQUEST_METHOD    => 'GET',
        QUERY_STRING      => '',
        SERVER_NAME       => 'everything2.com',
        SERVER_PORT       => 80,
        'psgi.input'      => $in,
        'psgi.url_scheme' => 'http',
        'psgi.version'    => [1, 1],
        'psgi.errors'     => \*STDERR,
        %over,
    };
}

#############################################################################
# The additive Plack::Request backing (docs/plack-request-migration.md
# prerequisite): Everything::Request->req is a Plack::Request built from the
# threaded PSGI env. The CGI backing is unchanged and still primary; this only
# proves the new seam is wired and reads the request correctly.
#############################################################################

subtest 'req is a Plack::Request built from the threaded env' => sub {
    my $env = make_env(
        REQUEST_METHOD => 'GET',
        QUERY_STRING   => 'op=vote&node_id=42&tag=a&tag=b&empty=',
        HTTP_COOKIE    => 'userpass=root%7Cabc; theme=kernelblue',
        HTTP_X_AJAX_IDLE => '1',
        HTTP_USER_AGENT  => 'parity-test-agent',
    );
    local $Everything::Request::PSGI_ENV = $env;

    my $REQUEST = Everything::Request->new;
    my $req = $REQUEST->req;

    isa_ok($req, 'Plack::Request', 'req');
    is($req->method, 'GET', 'method');
    is($req->param('op'), 'vote', 'scalar param read');
    is($req->param('node_id'), 42, 'numeric param read');
    is_deeply([$req->parameters->get_all('tag')], ['a', 'b'], 'multi-value param');
    is($req->param('empty'), '', 'empty-valued param is empty string, not undef');
    is($req->cookies->{userpass}, 'root|abc', 'cookie value url-decoded');
    is($req->cookies->{theme}, 'kernelblue', 'second cookie');
    is($req->headers->header('X-Ajax-Idle'), '1', 'request header read');
    is($req->headers->header('User-Agent'), 'parity-test-agent', 'user-agent header');
};

subtest 'req method reflects POST and the env is per-request (localized)' => sub {
    my $env = make_env(REQUEST_METHOD => 'POST', QUERY_STRING => 'a=1');
    local $Everything::Request::PSGI_ENV = $env;
    my $REQUEST = Everything::Request->new;
    is($REQUEST->req->method, 'POST', 'POST method');
    is($REQUEST->req->param('a'), 1, 'query param on a POST');
};

subtest 'psgi_env falls back to %ENV when nothing is threaded' => sub {
    local $Everything::Request::PSGI_ENV;   # ensure unset
    local %ENV = (%ENV, REQUEST_METHOD => 'PUT', QUERY_STRING => 'z=9');
    my $REQUEST = Everything::Request->new;
    my $env = $REQUEST->psgi_env;
    ok($env->{'psgi.input'}, 'fallback env synthesizes psgi.input');
    is($env->{REQUEST_METHOD}, 'PUT', 'fallback carries REQUEST_METHOD from %ENV');
    is($REQUEST->req->method, 'PUT', 'req built from the fallback env');
};

subtest 'the query object is now Plack-backed (PlackQuery), sharing the one req' => sub {
    my $env = make_env(QUERY_STRING => 'op=test&node_id=9');
    local $Everything::Request::PSGI_ENV = $env;
    my $REQUEST = Everything::Request->new;
    # Post-flip: ->cgi is the Plack-backed drop-in, NOT a CGI.pm instance.
    isa_ok($REQUEST->cgi, 'Everything::Request::PlackQuery', 'cgi is the Plack-backed query');
    isa_ok($REQUEST->req, 'Plack::Request', 'req is the Plack::Request');
    is($REQUEST->cgi->req, $REQUEST->req, 'cgi and req share the SAME Plack::Request (one parse)');
    # The façade reads (delegated via `handles`) work through PlackQuery.
    is($REQUEST->param('op'), 'test', 'facade ->param read through PlackQuery');
    is($REQUEST->param('node_id'), 9, 'facade ->param numeric');
};

done_testing();
