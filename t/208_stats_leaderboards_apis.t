#!/usr/bin/perl -w
# Statistics + leaderboard reports tranche (#4546): everything_statistics, user_statistics,
# everything_s_richest_noders, everything_s_biggest_stars, level_distribution, and the editor-only
# everything_s_best_writeups. Each moved its read-only aggregate query out of a Page (now a pure
# gate) into an API. Numeric fields must encode as JSON numbers, not strings (#4152).

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use JSON;
use Everything;
use Everything::API::everything_statistics;
use Everything::API::user_statistics;
use Everything::API::everything_s_richest_noders;
use Everything::API::everything_s_biggest_stars;
use Everything::API::level_distribution;
use Everything::API::everything_s_best_writeups;
use MockRequest;

initEverything('development-docker');
ok($DB, 'DB connection established');

my $root = $DB->getNode('root', 'user');

my $guest  = sub { MockRequest->new(is_guest_flag => 1) };
my $member = sub { MockRequest->new(is_guest_flag => 0, node_id => 1, title => 'mockmember') };
my $admin  = sub { MockRequest->new(is_guest_flag => 0, node_id => $root->{node_id}, nodedata => $root) };

my $J = JSON->new;

#############################################################################
# everything_statistics -- site-wide counts (admin-only: restricted superdoc)
#############################################################################
{
    my $api = Everything::API::everything_statistics->new;
    is_deeply($api->routes, { '/' => 'list' }, 'everything_statistics: routes');
    is($api->list($guest->())->[1]{state}, 'guest', 'everything_statistics: guest -> guest state');
    is($api->list($member->())->[1]{state}, 'permission', 'everything_statistics: non-admin -> permission');
    my $r = $api->list($admin->());
    is($r->[1]{success}, 1, 'everything_statistics: admin ok');
    ok(exists $r->[1]{total_nodes} && exists $r->[1]{total_users}, 'everything_statistics: has counts');
    # counts are JSON numbers, not strings (#4152)
    unlike($J->encode($r->[1]), qr/"total_(?:nodes|writeups|users|links)"\s*:\s*"/,
        'everything_statistics: counts are JSON numbers');
}

#############################################################################
# user_statistics -- login-activity counts (admin-only: restricted superdoc)
#############################################################################
{
    my $api = Everything::API::user_statistics->new;
    is($api->list($guest->())->[1]{state}, 'guest', 'user_statistics: guest -> guest state');
    is($api->list($member->())->[1]{state}, 'permission', 'user_statistics: non-admin -> permission');
    my $r = $api->list($admin->());
    is($r->[1]{success}, 1, 'user_statistics: admin ok');
    ok(exists $r->[1]{users_last_24h} && exists $r->[1]{users_last_4weeks}, 'user_statistics: has windows');
    unlike($J->encode($r->[1]), qr/"users_last_\w+"\s*:\s*"/, 'user_statistics: counts are JSON numbers');
}

#############################################################################
# everything_s_richest_noders -- GP leaderboard (admin-only: restricted superdoc)
#############################################################################
{
    my $api = Everything::API::everything_s_richest_noders->new;
    is($api->list($guest->())->[1]{state}, 'guest', 'richest_noders: guest -> guest state');
    is($api->list($member->())->[1]{state}, 'permission', 'richest_noders: non-admin -> permission');
    my $r = $api->list($admin->());
    is($r->[1]{success}, 1, 'richest_noders: admin ok');
    ok(ref($r->[1]{richest_all}) eq 'ARRAY', 'richest_noders: richest_all is an array');
    ok(ref($r->[1]{poorest}) eq 'ARRAY' && ref($r->[1]{richest_top}) eq 'ARRAY', 'richest_noders: poorest/top arrays');
    # gp + total_gp are JSON numbers, not strings (#4152)
    unlike($J->encode($r->[1]), qr/"(?:gp|total_gp|top_percentage)"\s*:\s*"/, 'richest_noders: gp fields are JSON numbers');
}

#############################################################################
# everything_s_biggest_stars -- top by stars
#############################################################################
{
    my $api = Everything::API::everything_s_biggest_stars->new;
    my $r = $api->list($guest->());
    is($r->[1]{success}, 1, 'biggest_stars: ok');
    ok(ref($r->[1]{users}) eq 'ARRAY', 'biggest_stars: users array');
    is($r->[1]{limit}, 100, 'biggest_stars: limit 100');
    if (@{ $r->[1]{users} }) {
        unlike($J->encode($r->[1]{users}[0]), qr/"(?:node_id|stars)"\s*:\s*"/, 'biggest_stars: node_id/stars are JSON numbers');
    }
}

#############################################################################
# level_distribution -- active users per level
#############################################################################
{
    my $api = Everything::API::level_distribution->new;
    my $r = $api->list($guest->());
    is($r->[1]{success}, 1, 'level_distribution: ok');
    ok(ref($r->[1]{levels}) eq 'ARRAY', 'level_distribution: levels array');
    if (@{ $r->[1]{levels} }) {
        unlike($J->encode($r->[1]{levels}[0]), qr/"(?:level|count)"\s*:\s*"/, 'level_distribution: level/count are JSON numbers');
    }
}

#############################################################################
# everything_s_best_writeups -- editor only (gate lives in the API)
#############################################################################
{
    my $api = Everything::API::everything_s_best_writeups->new;
    is($api->list($guest->())->[1]{state}, 'guest', 'best_writeups: guest -> guest state');
    is($api->list($member->())->[1]{state}, 'permission', 'best_writeups: non-editor -> permission');
    my $r = $api->list($admin->());
    is($r->[1]{success}, 1, 'best_writeups: editor/admin -> ok');
    ok(ref($r->[1]{writeups}) eq 'ARRAY', 'best_writeups: writeups array');
}

done_testing();
