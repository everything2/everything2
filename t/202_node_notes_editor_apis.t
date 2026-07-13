#!/usr/bin/perl -w
# The node-notes + editor-tools report -> API tranche (#4528): recent_node_notes,
# node_notes_by_editor, editor_endorsements. Each moved its params + query out of a Page
# (now a pure gate) into an API.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::API::recent_node_notes;
use Everything::API::node_notes_by_editor;
use Everything::API::editor_endorsements;
use MockRequest;

initEverything('development-docker');
ok($DB, 'DB connection established');

my $editor    = sub { MockRequest->new(is_editor_flag => 1, is_guest_flag => 0, query_params => { %{$_[0] || {}} }) };
my $noneditor = sub { MockRequest->new(is_editor_flag => 0, is_guest_flag => 0, query_params => { %{$_[0] || {}} }) };
my $admin     = sub { MockRequest->new(is_admin_flag  => 1, is_guest_flag => 0, query_params => { %{$_[0] || {}} }) };
my $nonadmin  = sub { MockRequest->new(is_admin_flag  => 0, is_guest_flag => 0, query_params => { %{$_[0] || {}} }) };

#############################################################################
# recent_node_notes -- editor/staff only
#############################################################################
my $rnn = Everything::API::recent_node_notes->new;
is_deeply($rnn->routes, { '/' => 'list' }, 'recent_node_notes: routes');

is($rnn->list($noneditor->())->[1]{state}, 'staff', 'recent_node_notes: non-editor -> staff state');
is($rnn->list($noneditor->())->[1]{success}, 0, 'recent_node_notes: non-editor -> success 0');

my $r = $rnn->list($editor->({ page => 0 }));
is($r->[1]{success}, 1, 'recent_node_notes: editor ok');
ok(ref($r->[1]{notes}) eq 'ARRAY', 'recent_node_notes: notes array');
ok(exists $r->[1]{total} && exists $r->[1]{page} && exists $r->[1]{perpage},
    'recent_node_notes: pagination fields');
is($r->[1]{hidesystemnotes}, 1, 'recent_node_notes: hidesystemnotes defaults on');

#############################################################################
# node_notes_by_editor -- admin only
#############################################################################
my $nnbe = Everything::API::node_notes_by_editor->new;
is($nnbe->list($nonadmin->())->[1]{state}, 'admin', 'node_notes_by_editor: non-admin -> admin state');

# no targetUser/gotime -> empty shell (React shows the search form)
my $shell = $nnbe->list($admin->());
is($shell->[1]{success}, 1, 'node_notes_by_editor: admin no-search -> success shell');
is_deeply($shell->[1]{notes}, [], 'node_notes_by_editor: no-search -> empty notes');

# a bogus user -> user_not_found state
is($nnbe->list($admin->({ targetUser => 'no_such_user_zzz', gotime => 'Go!' }))->[1]{state},
    'user_not_found', 'node_notes_by_editor: unknown user -> user_not_found');

# a real user (root) -> success with counted notes
my $n = $nnbe->list($admin->({ targetUser => 'root', gotime => 'Go!' }));
is($n->[1]{success}, 1, 'node_notes_by_editor: root ok');
is($n->[1]{target_username}, 'root', 'node_notes_by_editor: target echoed');
ok(exists $n->[1]{total_count} && ref($n->[1]{notes}) eq 'ARRAY',
    'node_notes_by_editor: total_count + notes');
# limit is capped at 100
is($nnbe->list($admin->({ targetUser => 'root', gotime => 'Go!', limit => 9999 }))->[1]{limit}, 100,
    'node_notes_by_editor: limit capped at 100');

#############################################################################
# editor_endorsements -- public
#############################################################################
my $ee = Everything::API::editor_endorsements->new;
my $e = $ee->list(MockRequest->new(query_params => {}));
is($e->[1]{success}, 1, 'editor_endorsements: success (public, no gate)');
ok(ref($e->[1]{editors}) eq 'ARRAY', 'editor_endorsements: editors array');
is($e->[1]{selected_editor}, undef, 'editor_endorsements: no editor selected by default');

# selecting root (node_id 113) -> selected_editor populated, endorsements array
my $es = $ee->list(MockRequest->new(query_params => { editor => 113 }));
is($es->[1]{success}, 1, 'editor_endorsements: selection ok');
is($es->[1]{selected_editor}{node_id}, 113, 'editor_endorsements: selected editor echoed');
ok(ref($es->[1]{endorsements}) eq 'ARRAY', 'editor_endorsements: endorsements array');

# a garbage editor id (injection) is stripped to digits, never interpolated raw
my $bad = $ee->list(MockRequest->new(query_params => { editor => '113; DROP TABLE node' }));
is($bad->[1]{success}, 1, 'editor_endorsements: garbage editor id survives (digits-only, injection-safe)');

done_testing();
