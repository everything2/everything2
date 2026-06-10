#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::API::password;
use MockRequest;

# Everything::API::password -- POST /api/password/reset-request. The reset/activation
# flow. This test pins the input-validation gauntlet, all of which returns BEFORE any
# email is sent or token generated, so nothing leaves the process and no user is
# mutated. (The happy path sends real mail, so it is intentionally not exercised here;
# the unknown-user case stops one step short of that.)

initEverything('development-docker');

ok($DB,  'Database connection established');
ok($APP, 'Application object created');

my $api = Everything::API::password->new();
ok($api, 'Created password API instance');

is_deeply($api->routes, { 'reset-request' => 'reset_request' },
    'routes: reset-request -> reset_request');

# Helper: run reset_request with a given POST body.
sub req {
    my (%post) = @_;
    return $api->reset_request(MockRequest->new(postdata => { %post }));
}

# Every validation failure is HTTP 200 with success=0 (E2 API convention).
my @cases = (
    {   name => 'missing who',
        post => {},
        err  => qr/username or email/i,
    },
    {   name => 'missing password',
        post => { who => 'root' },
        err  => qr/enter a new password/i,
    },
    {   name => 'password mismatch',
        post => { who => 'root', password => 'abcdef', passwordConfirm => 'abcdeX' },
        err  => qr/don't match/i,
    },
    {   name => 'password too short',
        post => { who => 'root', password => 'abc', passwordConfirm => 'abc' },
        err  => qr/at least 6 characters/i,
    },
    {   name => 'unknown user',
        post => { who => 'no_such_user_zzz_12345', password => 'abcdef', passwordConfirm => 'abcdef' },
        err  => qr/unknown user or email/i,
    },
);

for my $c (@cases) {
    my $r = req(%{ $c->{post} });
    is($r->[0], $api->HTTP_OK, "$c->{name}: returns HTTP 200");
    is($r->[1]{success}, 0, "$c->{name}: success=0");
    like($r->[1]{error}, $c->{err}, "$c->{name}: correct error message");
}

# Validation order: a too-short password is caught before the unknown-user lookup,
# so a bad-everything request reports the password problem, not the user problem.
my $r = req(who => 'no_such_user_zzz_12345', password => 'ab', passwordConfirm => 'ab');
like($r->[1]{error}, qr/at least 6 characters/i,
    'length is validated before the user lookup');

done_testing();

=head1 NAME

t/135_password_api.t - Tests for Everything::API::password (reset-request validation)

=cut
