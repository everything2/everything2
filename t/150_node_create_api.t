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
use Everything::API::node;
use MockRequest;

$SIG{__WARN__} = sub {
    my $w = shift;
    warn $w unless $w =~ /Could not open log/ || $w =~ /Use of uninitialized value/;
};

initEverything('development-docker');

my $APP = $Everything::APP;
my $DB  = $APP->{db};
my $api = Everything::API::node->new();

ok($DB,  'Database connection established');
ok($api, 'Created node API instance');

my $root = $DB->getNode('root', 'user');

# Guest is blocked by the unauthorized_if_guest guard.
is($api->create(MockRequest->new(nodedata => {}, is_guest_flag => 1))->[0],
    $api->HTTP_UNAUTHORIZED, 'guest cannot create a node');

# Missing type/title -> 400.
is($api->create(MockRequest->new(
        node_id => $root->{node_id}, nodedata => $root, is_guest_flag => 0,
        postdata => { title => 'x' }))->[0],
    $api->HTTP_BAD_REQUEST, 'missing type -> HTTP_BAD_REQUEST');

# Happy path + existing-title behavior.
{
    my $title = 'Node Create API Test ' . time();
    my $req = MockRequest->new(
        node_id => $root->{node_id}, title => 'root', nodedata => $root,
        is_admin_flag => 1, is_guest_flag => 0,
        postdata => { type => 'collaboration', title => $title },
    );
    my ($status, $resp) = @{ $api->create($req) };
    is($status, $api->HTTP_OK, 'create returns HTTP_OK');
    ok($resp->{success}, 'create reports success');
    ok($resp->{node_id}, 'a node_id is returned');

    my $node = $DB->getNodeById($resp->{node_id}, 'force');
    ok($node && $node->{type}{title} eq 'collaboration', 'a collaboration node was created');

    # Creating the same title again returns the existing id (op=new's behavior).
    my $req2 = MockRequest->new(
        node_id => $root->{node_id}, nodedata => $root, is_guest_flag => 0,
        postdata => { type => 'collaboration', title => $title },
    );
    is($api->create($req2)->[1]->{node_id}, $resp->{node_id},
        'creating an existing title returns the same node_id');

    # Cleanup
    $DB->nukeNode($DB->getNodeById($resp->{node_id}, 'force'), -1);
}

# Unknown type -> success=0 (HTTP_OK with an error).
{
    my ($status, $resp) = @{ $api->create(MockRequest->new(
        node_id => $root->{node_id}, nodedata => $root, is_guest_flag => 0,
        postdata => { type => 'no_such_type_zzz', title => 'whatever' })) };
    is($status, $api->HTTP_OK, 'unknown type returns HTTP_OK');
    ok(!$resp->{success}, 'unknown type reports failure');
}

done_testing();
