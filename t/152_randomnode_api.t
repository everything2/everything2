#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions RequireExtendedFormatting RequireLineBoundaryMatching RequireDotMatchAnything)
## no critic (ValuesAndExpressions ProhibitInterpolationOfLiterals ProhibitMagicNumbers)

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "$FindBin::Bin/lib";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;
use Everything::API::randomnode;
use MockRequest;

$SIG{__WARN__} = sub {
    my $w = shift;
    warn $w unless $w =~ /Could not open log/ || $w =~ /Use of uninitialized value/;
};

initEverything('development-docker');

my $APP = $Everything::APP;
my $DB  = $APP->{db};
my $api = Everything::API::randomnode->new();

ok($api, 'Created randomnode API instance');

# GET /api/randomnode -> a real random node (from the randomnodes stash, or the
# live fallback if the stash isn't populated).
my ($status, $resp) = @{ $api->get_random(MockRequest->new()) };
is($status, $api->HTTP_OK, 'get_random returns HTTP_OK');
ok($resp->{success}, 'reports success');
ok($resp->{node_id}, 'returns a node_id');
ok($DB->getNodeById($resp->{node_id}), 'node_id resolves to a real node');

done_testing();
