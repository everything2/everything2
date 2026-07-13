#!/usr/bin/perl -w
# The user-activity report -> API tranche (#4526): homenode_inspector, caja_de_arena,
# everything_s_best_users. Each moved its params + query out of a Page (now a pure gate) into an API.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::API::homenode_inspector;
use Everything::API::caja_de_arena;
use Everything::API::everything_s_best_users;
use MockRequest;

initEverything('development-docker');
ok($DB, 'DB connection established');

my $admin = sub { MockRequest->new(is_admin_flag => 1, is_guest_flag => 0, query_params => { %{$_[0] || {}} }) };
my $nonadmin = sub { MockRequest->new(is_admin_flag => 0, is_guest_flag => 0, query_params => { %{$_[0] || {}} }) };

#############################################################################
# homenode_inspector -- admin only, goneunit whitelisted
#############################################################################
my $hi = Everything::API::homenode_inspector->new;
is_deeply($hi->routes, { '/' => 'list' }, 'homenode_inspector: routes');

is($hi->list($nonadmin->())->[1]{state}, 'admin', 'homenode_inspector: non-admin -> admin state');

my $h = $hi->list($admin->({ gonetime => 0, goneunit => 'month', maxwus => 100 }));
is($h->[1]{success}, 1, 'homenode_inspector: admin ok');
ok(ref($h->[1]{items}) eq 'ARRAY', 'homenode_inspector: items array');
ok(exists $h->[1]{total} && exists $h->[1]{total_pages}, 'homenode_inspector: pagination fields');
is($h->[1]{filters}{goneunit}, 'MONTH', 'homenode_inspector: goneunit canonicalized');
ok(exists $h->[1]{pole_id}, 'homenode_inspector: pole_id present');

# a non-whitelisted goneunit (injection attempt) is rejected as a param error, never interpolated
is($hi->list($admin->({ goneunit => 'month; DROP TABLE node' }))->[1]{state}, 'param',
    'homenode_inspector: bad goneunit -> param error (injection-safe)');
# non-numeric maxwus -> param error
is($hi->list($admin->({ maxwus => 'abc' }))->[1]{state}, 'param', 'homenode_inspector: non-numeric maxwus -> param');

#############################################################################
# caja_de_arena -- admin only, gonesince re-parsed
#############################################################################
my $cda = Everything::API::caja_de_arena->new;
is($cda->list($nonadmin->())->[1]{state}, 'admin', 'caja_de_arena: non-admin -> admin state');

my $c = $cda->list($admin->({ gonesince => '2 MONTH', published => 1 }));
is($c->[1]{success}, 1, 'caja_de_arena: admin ok');
is($c->[1]{filters}{gonesince}, '2 MONTH', 'caja_de_arena: gonesince parsed + canonicalized');
is($c->[1]{filters}{published}, 1, 'caja_de_arena: published echoed');
# a garbage gonesince (injection) falls back to the safe default
is($cda->list($admin->({ gonesince => "1 YEAR; DROP TABLE node" }))->[1]{filters}{gonesince}, '1 YEAR',
    'caja_de_arena: garbage gonesince -> 1 YEAR fallback (injection-safe)');

#############################################################################
# everything_s_best_users -- public, sortable
#############################################################################
my $ebu = Everything::API::everything_s_best_users->new;
my $b = $ebu->list(MockRequest->new(query_params => {}));
is($b->[1]{success}, 1, 'ebu: success (public, no gate)');
ok(ref($b->[1]{users}) eq 'ARRAY', 'ebu: users array');
is($b->[1]{showDevotion}, 0, 'ebu: default not by devotion');

my $bd = $ebu->list(MockRequest->new(query_params => { ebu_showdevotion => 1 }));
is($bd->[1]{showDevotion}, 1, 'ebu: showDevotion echoed');
# when there are >=2 users, the devotion sort is non-increasing
my @us = @{ $bd->[1]{users} };
if (@us >= 2) {
    my $ok = 1;
    for my $i (1 .. $#us) { $ok = 0 if $us[$i]{devotion} > $us[$i-1]{devotion} }
    ok($ok, 'ebu: users sorted by devotion (non-increasing)');
} else {
    ok(1, 'ebu: (fewer than 2 users in dev; sort order trivially holds)');
}

done_testing();
