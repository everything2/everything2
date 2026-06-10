#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::API::writeuptypes;
use MockRequest;

# Everything::API::writeuptypes -- GET /api/writeuptypes -> the list of writeup types.
# Read-only, unauthenticated. Pins the list contract.

initEverything('development-docker');

ok($DB,  'Database connection established');
ok($APP, 'Application object created');

my $api = Everything::API::writeuptypes->new();
ok($api, 'Created writeuptypes API instance');

is_deeply($api->routes, { '/' => 'list' }, 'routes: / -> list');

my $request = MockRequest->new();   # guest is fine; the list is public

my $result = $api->list($request);
is($result->[0], $api->HTTP_OK, 'list returns HTTP 200');
is($result->[1]{success}, 1, 'list succeeds');
ok(ref $result->[1]{writeuptypes} eq 'ARRAY', 'writeuptypes is an array');
ok(scalar(@{$result->[1]{writeuptypes}}) > 0, 'at least one writeup type returned');

my $first = $result->[1]{writeuptypes}[0];
ok(defined $first->{node_id}, 'each entry has a node_id');
ok(defined $first->{title},   'each entry has a title');
like($first->{node_id}, qr/^\d+$/, 'node_id is numeric');

# Sorted by title ascending (per the query's ORDER BY title).
my @titles = map { $_->{title} } @{$result->[1]{writeuptypes}};
is_deeply(\@titles, [ sort @titles ], 'writeuptypes are sorted by title');

# The canonical core types should be present.
my %have = map { $_->{title} => 1 } @{$result->[1]{writeuptypes}};
ok($have{thing} || $have{idea} || $have{person} || $have{place},
   'a recognizable core writeup type is present');

done_testing();

=head1 NAME

t/132_writeuptypes_api.t - Tests for Everything::API::writeuptypes

=cut
