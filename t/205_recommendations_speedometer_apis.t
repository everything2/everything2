#!/usr/bin/perl -w
# The recommendation-engines + speedometer tranche (#4539): do_you_c_what_i_c + the_recommender
# collapse into one /api/recommendations (signal=cool|bookmark); noding_speedometer becomes
# /api/noding_speedometer (NoGuest). Each moved its params + query out of a Page (now a pure gate).

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use JSON;
use Everything;
use Everything::API::recommendations;
use Everything::API::noding_speedometer;
use MockRequest;

initEverything('development-docker');
ok($DB, 'DB connection established');

my $member = sub { MockRequest->new(is_guest_flag => 0, node_id => 1, title => 'mockmember', query_params => { %{$_[0] || {}} }) };
my $guest  = sub { MockRequest->new(is_guest_flag => 1, query_params => { %{$_[0] || {}} }) };

#############################################################################
# recommendations -- signal switching, clamp, error states
#############################################################################
my $rec = Everything::API::recommendations->new;
is_deeply($rec->routes, { '/' => 'list' }, 'recommendations: routes');

# a mock member with no cools/bookmarks -> no_signal, signal echoed
my $c = $rec->list($member->({ signal => 'cool' }));
is($c->[1]{state}, 'no_signal', 'recommendations: no cools -> no_signal');
is($c->[1]{signal}, 'cool', 'recommendations: signal=cool echoed');

my $b = $rec->list($member->({ signal => 'bookmark' }));
is($b->[1]{state}, 'no_signal', 'recommendations: no bookmarks -> no_signal');
is($b->[1]{signal}, 'bookmark', 'recommendations: signal=bookmark echoed');

# an unknown signal falls back to cool
is($rec->list($member->({ signal => 'garbage' }))->[1]{signal}, 'cool',
    'recommendations: unknown signal -> cool');

# maxcools validated (1..100), else default 10
is($rec->list($member->({ maxcools => 50 }))->[1]{maxcools}, 50, 'recommendations: maxcools 50 kept');
is($rec->list($member->({ maxcools => 999 }))->[1]{maxcools}, 10, 'recommendations: maxcools>100 -> 10');
is($rec->list($member->({ maxcools => 'abc' }))->[1]{maxcools}, 10, 'recommendations: non-numeric maxcools -> 10');

# unknown cooluser -> user_not_found
is($rec->list($member->({ cooluser => 'no_such_user_zzz' }))->[1]{state}, 'user_not_found',
    'recommendations: unknown cooluser -> user_not_found');

# a real user with cools runs the full algorithm (recommendations may be empty on sparse dev data)
my $real = $rec->list($member->({ signal => 'cool', cooluser => 'normaluser5', maxcools => 100 }));
if ($real->[1]{success}) {
    ok($real->[1]{num_signal_sampled} > 0, 'recommendations: real cooler sampled some cools');
    ok(ref($real->[1]{recommendations}) eq 'ARRAY', 'recommendations: recommendations is an array');
} else {
    is($real->[1]{state}, 'no_signal', 'recommendations: (dev) normaluser5 has no cools -> no_signal');
}

#############################################################################
# noding_speedometer -- NoGuest, clamp, states, speed calc
#############################################################################
my $spd = Everything::API::noding_speedometer->new;
is($spd->list($guest->())->[1]{state}, 'guest', 'noding_speedometer: guest -> guest state');

# no speedyuser -> form shell (success, no speed)
my $shell = $spd->list($member->());
is($shell->[1]{success}, 1, 'noding_speedometer: no user -> shell success');
ok(!exists $shell->[1]{speed}, 'noding_speedometer: shell has no speed');
is($shell->[1]{username}, 'mockmember', 'noding_speedometer: shell defaults to viewer name');

# unknown user
is($spd->list($member->({ speedyuser => 'no_such_user_zzz' }))->[1]{state}, 'user_not_found',
    'noding_speedometer: unknown user -> user_not_found');

# clocknodes clamps to a positive int
is($spd->list($member->({ speedyuser => 'root', clocknodes => 'abc' }))->[1]{clock_nodes}, 50,
    'noding_speedometer: non-numeric clocknodes -> 50');
is($spd->list($member->({ speedyuser => 'root', clocknodes => -5 }))->[1]{clock_nodes}, 50,
    'noding_speedometer: negative clocknodes -> 50');

# root has plenty of writeups -> full speed calc
my $root = $spd->list($member->({ speedyuser => 'root', clocknodes => 20 }));
SKIP: {
    skip 'root has no writeups in dev', 4 unless $root->[1]{success} && exists $root->[1]{speed};
    like("$root->[1]{speed}", qr/^[\d.]+$/, 'noding_speedometer: speed is numeric');
    ok($root->[1]{total_writeups} > 0, 'noding_speedometer: total_writeups counted');
    ok(exists $root->[1]{level_data}{current_level}, 'noding_speedometer: level_data present');
    unlike(JSON->new->encode($root->[1]), qr/"speed"\s*:\s*"/, 'noding_speedometer: speed serializes as a number (#4108)');
}

done_testing();
