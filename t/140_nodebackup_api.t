#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::API::nodebackup;
use MockRequest;

# Everything::API::nodebackup -- POST /api/nodebackup/create zips a user's writeups/drafts
# to S3. Tests the login gate and the development-environment guard (the real backup needs
# S3 and is therefore unreachable in dev -- the controller refuses it explicitly, which is
# exactly what this pins).

initEverything('development-docker');

ok($DB,  'Database connection established');
ok($APP, 'Application object created');

my $api = Everything::API::nodebackup->new();
ok($api, 'Created nodebackup API instance');

is_deeply($api->routes, { 'create' => 'create_backup' }, 'routes: create -> create_backup');

#############################################################################
# Guest -> login required
#############################################################################

my $guest = MockRequest->new(is_guest_flag => 1);
my $r = $api->create_backup($guest);
is($r->[0], $api->HTTP_OK, 'guest create_backup returns 200');
is($r->[1]{success}, 0, 'guest cannot back up');
like($r->[1]{error}, qr/login required/i, 'login-required error');

#############################################################################
# Logged-in in the dev environment -> explicit S3-unavailable refusal
#############################################################################

my $normal_user = $DB->getNode('normaluser1', 'user');
ok($normal_user, 'got normaluser1');

my $logged_in = MockRequest->new(
    node_id       => $normal_user->{node_id},
    title         => $normal_user->{title},
    is_guest_flag => 0,
    nodedata      => $normal_user,
    vars          => {},
    postdata      => { contentType => 'both', format => 'both' },
);
$r = $api->create_backup($logged_in);
is($r->[0], $api->HTTP_OK, 'dev create_backup returns 200');
is($r->[1]{success}, 0, 'dev environment refuses the backup');
like($r->[1]{error}, qr/development environment|S3/i,
    'refusal explains S3 is unavailable in dev');

done_testing();

=head1 NAME

t/140_nodebackup_api.t - Tests for Everything::API::nodebackup (login gate + dev guard)

=cut
