#!/usr/bin/perl -w
# The usergroup-content-viewers tranche (#4541): usergroup_discussions + the list route added to
# usergroup_message_archive. Each moved its read/params out of a Page (now a pure gate) into an API.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use JSON;
use Everything;
use Everything::API::usergroup_discussions;
use Everything::API::usergroup_message_archive;
use MockRequest;

initEverything('development-docker');
ok($DB, 'DB connection established');

my $root   = $DB->getNode('root', 'user');
my $rootid = $root->{node_id};

my $guest  = sub { MockRequest->new(is_guest_flag => 1, query_params => { %{$_[0] || {}} }) };
my $member = sub { MockRequest->new(is_guest_flag => 0, node_id => $rootid, nodedata => $root, query_params => { %{$_[0] || {}} }) };

#############################################################################
# usergroup_discussions
#############################################################################
my $ugd = Everything::API::usergroup_discussions->new;
is_deeply($ugd->routes, { '/' => 'list' }, 'usergroup_discussions: routes');

is($ugd->list($guest->())->[1]{state}, 'guest', 'usergroup_discussions: guest -> guest state');

my $d = $ugd->list($member->());
is($d->[1]{success}, 1, 'usergroup_discussions: member ok');
ok(ref($d->[1]{usergroups}) eq 'ARRAY' && @{$d->[1]{usergroups}} > 0, 'usergroup_discussions: root has usergroups');
ok(ref($d->[1]{discussions}) eq 'ARRAY', 'usergroup_discussions: discussions array');
ok(exists $d->[1]{total_discussions} && exists $d->[1]{offset}, 'usergroup_discussions: pagination fields');
# selected_usergroup must be a JSON number, not a string (#4152)
unlike(JSON->new->encode($d->[1]), qr/"selected_usergroup"\s*:\s*"/, 'usergroup_discussions: selected_usergroup is a JSON number');

# a group the caller isn't in -> access_denied
is($ugd->list($member->({ show_ug => 99999999 }))->[1]{state}, 'access_denied',
    'usergroup_discussions: non-member group -> access_denied');

#############################################################################
# usergroup_message_archive -- list route (copy route lives alongside)
#############################################################################
my $uma = Everything::API::usergroup_message_archive->new;
is_deeply($uma->routes, { '/' => 'list', 'copy' => 'copy_messages' },
    'usergroup_message_archive: list + copy routes coexist');

is($uma->list($guest->())->[1]{state}, 'guest', 'usergroup_message_archive: guest -> guest state');

my $shell = $uma->list($member->());
is($shell->[1]{success}, 1, 'usergroup_message_archive: no viewgroup -> picker shell');
ok(ref($shell->[1]{archive_groups}) eq 'ARRAY', 'usergroup_message_archive: archive_groups array');
ok(!exists $shell->[1]{messages}, 'usergroup_message_archive: shell has no messages');

is($uma->list($member->({ viewgroup => 'no_such_group_zzz' }))->[1]{state}, 'no_such_group',
    'usergroup_message_archive: unknown group -> no_such_group');

# e2gods is an archive-enabled group root belongs to -> full view
my $view = $uma->list($member->({ viewgroup => 'e2gods' }));
SKIP: {
    skip 'e2gods not viewable in dev', 3 unless $view->[1]{success} && $view->[1]{selected_group};
    is($view->[1]{selected_group}{title}, 'e2gods', 'usergroup_message_archive: selected group echoed');
    ok(ref($view->[1]{messages}) eq 'ARRAY', 'usergroup_message_archive: messages array');
    is(ref($view->[1]{reset_time}), 'SCALAR', 'usergroup_message_archive: reset_time is a JSON boolean (#4108)');
}

done_testing();
