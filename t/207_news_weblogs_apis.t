#!/usr/bin/perl -w
# The news-weblogs tranche (#4543): news_for_noders + news_archives. Each moved its weblog read +
# params out of a Page (now a pure gate) into an API.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use JSON;
use Everything;
use Everything::API::news_for_noders;
use Everything::API::news_archives;
use MockRequest;

initEverything('development-docker');
ok($DB, 'DB connection established');

my $root = $DB->getNode('root', 'user');

my $guest  = sub { MockRequest->new(is_guest_flag => 1, query_params => { %{$_[0] || {}} }) };
my $member = sub { MockRequest->new(is_guest_flag => 0, node_id => 1, title => 'mockmember', query_params => { %{$_[0] || {}} }) };
my $admin  = sub { MockRequest->new(is_guest_flag => 0, node_id => $root->{node_id}, nodedata => $root, query_params => { %{$_[0] || {}} }) };

#############################################################################
# news_for_noders -- public news weblog
#############################################################################
my $nfn = Everything::API::news_for_noders->new;
is_deeply($nfn->routes, { '/' => 'list' }, 'news_for_noders: routes');

my $n = $nfn->list($member->());
is($n->[1]{success}, 1, 'news_for_noders: ok');
ok(ref($n->[1]{entries}) eq 'ARRAY', 'news_for_noders: entries array');
ok(exists $n->[1]{has_older} && exists $n->[1]{next_older}, 'news_for_noders: pagination fields');
# weblog_id is a JSON number, not a string (#4152)
unlike(JSON->new->encode($n->[1]), qr/"weblog_id"\s*:\s*"/, 'news_for_noders: weblog_id is a JSON number');
# has_older / can_remove are JSON booleans (#4108)
is(ref($n->[1]{has_older}), 'SCALAR', 'news_for_noders: has_older is a JSON boolean');
is(ref($n->[1]{can_remove}), 'SCALAR', 'news_for_noders: can_remove is a JSON boolean');

# a bare member can't remove; an admin can
is(${ $nfn->list($member->())->[1]{can_remove} }, 0, 'news_for_noders: non-admin cannot remove');
is(${ $nfn->list($admin->())->[1]{can_remove} },  1, 'news_for_noders: admin can remove');

# guests may read the news
is($nfn->list($guest->())->[1]{success}, 1, 'news_for_noders: guest can read (public)');

#############################################################################
# news_archives -- NoGuest
#############################################################################
my $na = Everything::API::news_archives->new;
is($na->list($guest->())->[1]{state}, 'guest', 'news_archives: guest -> guest state');

my $a = $na->list($member->());
is($a->[1]{success}, 1, 'news_archives: member ok');
ok(ref($a->[1]{groups}) eq 'ARRAY' && @{$a->[1]{groups}} > 0, 'news_archives: groups w/ entries');
is($a->[1]{viewWeblog}, undef, 'news_archives: no view_weblog -> list only');
# group node_ids are JSON numbers (#4152)
unlike(JSON->new->encode($a->[1]{groups}[0]), qr/"node_id"\s*:\s*"/, 'news_archives: group node_id is a JSON number');

# gods (114) archive is editor-only -> a bare member gets permission-denied
is($na->list($member->({ view_weblog => 114 }))->[1]{state}, 'permission',
    'news_archives: non-editor viewing gods archive -> permission');

# a non-numeric view_weblog is stripped to digits (injection-safe) -> treated as no view
is($na->list($member->({ view_weblog => 'abc; DROP TABLE weblog' }))->[1]{viewWeblog}, undef,
    'news_archives: garbage view_weblog stripped to nothing (injection-safe)');

done_testing();
