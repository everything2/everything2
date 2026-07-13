#!/usr/bin/perl -w
# The report-controller -> API tranche (#4524): writeups_by_type, nodes_of_the_year,
# my_big_writeup_list. Each moved its params + query out of a Page (now a pure gate) into an API.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::API::writeups_by_type;
use Everything::API::nodes_of_the_year;
use Everything::API::my_big_writeup_list;
use MockRequest;

initEverything('development-docker');
ok($DB, 'DB connection established');

#############################################################################
# writeups_by_type
#############################################################################
my $wbt = Everything::API::writeups_by_type->new;
is_deeply($wbt->routes, { '/' => 'list' }, 'writeups_by_type: routes');

my $r = $wbt->list(MockRequest->new(query_params => { count => 10, page => 0 }));
is($r->[0], $wbt->HTTP_OK, 'writeups_by_type: HTTP 200');
is($r->[1]{success}, 1, 'writeups_by_type: success');
ok(ref($r->[1]{writeups}) eq 'ARRAY', 'writeups_by_type: writeups is an array');
is($r->[1]{current_count}, 10, 'writeups_by_type: echoes count');
ok(scalar(@{$r->[1]{type_options}}) >= 1, 'writeups_by_type: type_options present');
is($r->[1]{type_options}[0]{value}, 0, 'writeups_by_type: first type option is All (value 0)');
ok(!exists $r->[1]{count_options}, 'writeups_by_type: static count_options NOT shipped (React owns it)');
# count clamp: an absurd count is bounded to 50
is($wbt->list(MockRequest->new(query_params => { count => 99999 }))->[1]{current_count}, 50,
    'writeups_by_type: out-of-range count clamped to 50');

#############################################################################
# nodes_of_the_year
#############################################################################
my $noty = Everything::API::nodes_of_the_year->new;
my $y = $noty->list(MockRequest->new(query_params => { count => 5, year => 2020 }));
is($y->[1]{success}, 1, 'nodes_of_the_year: success');
is($y->[1]{year}, 2020, 'nodes_of_the_year: echoes the requested year');
ok(ref($y->[1]{writeups}) eq 'ARRAY', 'nodes_of_the_year: writeups is an array');
ok(scalar(@{$y->[1]{writeup_types}}) >= 1, 'nodes_of_the_year: writeup_types present');
# orderby whitelist: a valid one is kept, an injection attempt falls back to the default
is($noty->list(MockRequest->new(query_params => { orderby => 'reputation DESC' }))->[1]{orderby},
    'reputation DESC', 'nodes_of_the_year: a whitelisted orderby is honored');
is($noty->list(MockRequest->new(query_params => { orderby => '1;DROP TABLE node' }))->[1]{orderby},
    'cooled DESC,reputation DESC', 'nodes_of_the_year: a non-whitelisted orderby falls back (injection-safe)');

#############################################################################
# my_big_writeup_list
#############################################################################
my $mbwl = Everything::API::my_big_writeup_list->new;

# Guest -> guest state
my $guest = $mbwl->list(MockRequest->new(is_guest_flag => 1));
is($guest->[1]{success}, 0, 'mbwl: guest denied');
is($guest->[1]{state}, 'guest', 'mbwl: guest state');

# A logged-in user looking up a non-existent user -> user_not_found + the searched name
my $notfound = $mbwl->list(MockRequest->new(title => 'root', is_guest_flag => 0, query_params => { usersearch => 'no_such_user_zzz_' . time() }));
is($notfound->[1]{state}, 'user_not_found', 'mbwl: unknown user -> user_not_found');
ok(!exists $notfound->[1]{writeups}, 'mbwl: user_not_found ships no writeups');

# Bot easter-eggs short-circuit with their own state (copy lives in React)
is($mbwl->list(MockRequest->new(title => 'root', is_guest_flag => 0, query_params => { usersearch => 'EDB' }))->[1]{state},
    'edb', 'mbwl: EDB -> edb state');
is($mbwl->list(MockRequest->new(title => 'root', is_guest_flag => 0, query_params => { usersearch => 'Webster 1913' }))->[1]{state},
    'webster', 'mbwl: Webster 1913 -> webster state');

# root looking at their own list: success, rep visible (is_me), writeups present
my $root = $DB->getNode('root', 'user');
my $own = $mbwl->list(MockRequest->new(node_id => $root->{node_id}, title => 'root'));
is($own->[1]{success}, 1, 'mbwl: own list succeeds');
is($own->[1]{is_me}, 1, 'mbwl: is_me for own list');
is($own->[1]{show_rep}, 1, 'mbwl: rep visible on own list');
ok(scalar(@{$own->[1]{writeups}}), 'mbwl: own list has writeups');
ok(exists $own->[1]{writeups}[0]{reputation}, 'mbwl: reputation present for own writeups');
ok(!exists $own->[1]{state}, 'mbwl: no error state on success');

done_testing();
