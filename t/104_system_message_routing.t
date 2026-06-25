#!/usr/bin/perl
#
# 104_system_message_routing.t
#
# Comprehensive coverage of the system-bot message-sending paths after the
# #4142 refactor:
#
#   * Application::sendPrivateMessage accepts integer ids, stub hashrefs,
#     full hashrefs, and string titles. Every form must honor
#     message_forward_to and messageignore.
#   * Every system-bot caller (cool, easter_eggs, tokenator, sanctify) now
#     routes through sendPrivateMessage. Notifications must end up in the
#     forwarded inbox when the target has message_forward_to set, and must
#     not be delivered at all when the bot is ignored.
#   * cool.pm specifically still respects the per-author no_coolnotification
#     user-var. That gate lives in the cool API by design — it's cool-
#     specific opt-out, not a general message rule.
#
# Test users are created at setup and torn down at the end so this file can
# run idempotently against an existing dev DB.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::Application;
use Everything::API::cool;
use Everything::API::easter_eggs;

initEverything('development-docker');

my $APP = $Everything::APP;
my $DB  = $APP->{db};

# Every node/user this test creates is tracked here and swept in the END block
# below, which runs even if a subtest dies mid-way. Without this the bookmark/cool
# subtests orphaned "Test writeup for ..." nodes (and their now-deleted authors)
# on every failing run. (#4142 follow-up)
my @CREATED_NODES;
END {
    return unless $DB && $DB->{dbh};
    eval {
        my %seen;
        for my $id (grep { $_ && !$seen{$_}++ } @CREATED_NODES) {
            $DB->sqlDelete('writeup',   "writeup_id=$id");
            $DB->sqlDelete('e2node',    "e2node_id=$id");
            $DB->sqlDelete('document',  "document_id=$id");
            $DB->sqlDelete('nodegroup', "nodegroup_id=$id OR node_id=$id");
            $DB->sqlDelete('links',     "from_node=$id OR to_node=$id");
            $DB->sqlDelete('user',      "user_id=$id");
            $DB->sqlDelete('node',      "node_id=$id");
        }
        1;
    };
}

ok($APP, 'application initialized');

# -- Test users ------------------------------------------------------------
# Create three users:
#   * $forward_target  — destination of forwarded messages
#   * $forward_source  — has message_forward_to = $forward_target->{user_id}
#   * $ignores_cme     — ignores Cool Man Eddie via messageignore
# Plus a "cooler" to actually perform actions.

sub setup_user {
    my ($name, $extra_fields) = @_;
    my $existing = $DB->getNode($name, 'user');
    if ($existing) { push @CREATED_NODES, $existing->{node_id}; return $existing; }
    my $id = $DB->insertNode($name, 'user', -1, $extra_fields || {});
    push @CREATED_NODES, $id;
    return $DB->getNodeById($id);
}

my $forward_target = setup_user('test_fwd_target_4142');
my $forward_source = setup_user('test_fwd_source_4142');
my $ignores_cme    = setup_user('test_ignores_cme_4142');
my $plain_user     = setup_user('test_plain_4142');
my $cooler         = setup_user('test_cooler_4142');

# Wire forward_source → forward_target
$forward_source->{message_forward_to} = $forward_target->{user_id};
$DB->updateNode($forward_source, -1);
# Reload to make sure the in-memory hash reflects DB state
$forward_source = $DB->getNodeById($forward_source->{node_id});
is($forward_source->{message_forward_to}, $forward_target->{user_id},
    'forward_source.message_forward_to is set');

my $eddie = $DB->getNode('Cool Man Eddie', 'user');
ok($eddie, 'Cool Man Eddie user exists');

# Wire messageignore: $ignores_cme blocks Cool Man Eddie
$DB->sqlDelete('messageignore',
    "messageignore_id=$ignores_cme->{node_id} AND ignore_node=$eddie->{node_id}");
$DB->sqlInsert('messageignore', {
    messageignore_id => $ignores_cme->{node_id},
    ignore_node      => $eddie->{node_id},
});

# Helper: get the most recent message addressed to a given user_id, optionally
# filtered by author. Returns undef if none.
sub latest_msg_to {
    my ($recipient_id, $author_id) = @_;
    my $where = "for_user=$recipient_id";
    $where .= " AND author_user=$author_id" if $author_id;
    return $DB->sqlSelectHashref('*', 'message',
        "$where ORDER BY message_id DESC LIMIT 1");
}

# Helper: count messages sent from $author to $recipient since a starting id.
sub count_msgs_since {
    my ($recipient_id, $author_id, $since_id) = @_;
    my ($n) = $DB->sqlSelect('COUNT(*)', 'message',
        "for_user=$recipient_id AND author_user=$author_id AND message_id > $since_id");
    return $n || 0;
}

# Snapshot the max message_id before each test, so we can detect new
# inserts without colliding with anything pre-existing.
sub max_msg_id {
    my ($n) = $DB->sqlSelect('MAX(message_id)', 'message');
    return $n || 0;
}

#############################################################################
# Section 1 — sendPrivateMessage accepts every reasonable recipient form
#############################################################################
subtest 'sendPrivateMessage: integer node_id recipient' => sub {
    my $before = max_msg_id();
    my $result = $APP->sendPrivateMessage($eddie, $plain_user->{user_id},
        'integer-id test');
    ok($result->{success}, 'integer recipient succeeds');
    my $msg = $DB->sqlSelectHashref('*', 'message',
        "for_user=$plain_user->{user_id} AND author_user=$eddie->{node_id} AND message_id>$before");
    ok($msg, 'message landed in plain_user inbox');
    like($msg->{msgtext}, qr/integer-id test/, 'message text preserved');
    $DB->sqlDelete('message', "message_id=$msg->{message_id}") if $msg;
};

subtest 'sendPrivateMessage: stub hashref { user_id => N } recipient' => sub {
    my $before = max_msg_id();
    my $result = $APP->sendPrivateMessage($eddie,
        { user_id => $plain_user->{user_id} }, 'stub-hashref test');
    ok($result->{success}, 'stub recipient succeeds');
    my $msg = $DB->sqlSelectHashref('*', 'message',
        "for_user=$plain_user->{user_id} AND author_user=$eddie->{node_id} AND message_id>$before");
    ok($msg, 'message landed in plain_user inbox via stub');
    $DB->sqlDelete('message', "message_id=$msg->{message_id}") if $msg;
};

subtest 'sendPrivateMessage: full hashref recipient' => sub {
    my $before = max_msg_id();
    my $result = $APP->sendPrivateMessage($eddie, $plain_user,
        'full-hashref test');
    ok($result->{success}, 'full hashref recipient succeeds');
    my $msg = $DB->sqlSelectHashref('*', 'message',
        "for_user=$plain_user->{user_id} AND author_user=$eddie->{node_id} AND message_id>$before");
    ok($msg, 'message landed in plain_user inbox via full hashref');
    $DB->sqlDelete('message', "message_id=$msg->{message_id}") if $msg;
};

subtest 'sendPrivateMessage: string title recipient' => sub {
    my $before = max_msg_id();
    my $result = $APP->sendPrivateMessage($eddie, $plain_user->{title},
        'string-title test');
    ok($result->{success}, 'string recipient succeeds');
    my $msg = $DB->sqlSelectHashref('*', 'message',
        "for_user=$plain_user->{user_id} AND author_user=$eddie->{node_id} AND message_id>$before");
    ok($msg, 'message landed in plain_user inbox via string title');
    $DB->sqlDelete('message', "message_id=$msg->{message_id}") if $msg;
};

#############################################################################
# Section 2 — message_forward_to fires for every recipient form
#
# The #4142 regression was specifically that stub hashrefs (sanctify-style)
# silently bypassed forwarding. Test every form.
#############################################################################
subtest 'forwarding: integer id → lands in forward_target inbox' => sub {
    my $before = max_msg_id();
    my $result = $APP->sendPrivateMessage($eddie,
        $forward_source->{user_id}, 'fwd via integer');
    ok($result->{success}, 'send succeeded');
    is(latest_msg_to($forward_source->{user_id}, $eddie->{node_id}) // 'NONE',
       'NONE', 'no message landed in forward_source (forwarded away)')
        if !count_msgs_since($forward_source->{user_id}, $eddie->{node_id}, $before);
    my $target_msg = $DB->sqlSelectHashref('*', 'message',
        "for_user=$forward_target->{user_id} AND author_user=$eddie->{node_id} AND message_id>$before");
    ok($target_msg, 'message arrived at forward_target inbox');
    like($target_msg->{msgtext}, qr/fwd via integer/, 'message text preserved');
    $DB->sqlDelete('message', "message_id=$target_msg->{message_id}") if $target_msg;
};

subtest 'forwarding: stub hashref → lands in forward_target inbox (#4142 core fix)' => sub {
    my $before = max_msg_id();
    my $result = $APP->sendPrivateMessage($eddie,
        { user_id => $forward_source->{user_id} }, 'fwd via stub');
    ok($result->{success}, 'send succeeded');
    my $target_msg = $DB->sqlSelectHashref('*', 'message',
        "for_user=$forward_target->{user_id} AND author_user=$eddie->{node_id} AND message_id>$before");
    ok($target_msg, 'stub-form recipient forwarded — was the #4142 regression');
    my $src_count = count_msgs_since($forward_source->{user_id}, $eddie->{node_id}, $before);
    is($src_count, 0, 'no copy left in forward_source inbox');
    $DB->sqlDelete('message', "message_id=$target_msg->{message_id}") if $target_msg;
};

subtest 'forwarding: full hashref → lands in forward_target inbox' => sub {
    my $before = max_msg_id();
    my $result = $APP->sendPrivateMessage($eddie, $forward_source, 'fwd via full');
    ok($result->{success}, 'send succeeded');
    my $target_msg = $DB->sqlSelectHashref('*', 'message',
        "for_user=$forward_target->{user_id} AND author_user=$eddie->{node_id} AND message_id>$before");
    ok($target_msg, 'full-hashref form forwarded correctly');
    $DB->sqlDelete('message', "message_id=$target_msg->{message_id}") if $target_msg;
};

subtest 'forwarding: string title → lands in forward_target inbox' => sub {
    my $before = max_msg_id();
    my $result = $APP->sendPrivateMessage($eddie, $forward_source->{title},
        'fwd via string');
    ok($result->{success}, 'send succeeded');
    my $target_msg = $DB->sqlSelectHashref('*', 'message',
        "for_user=$forward_target->{user_id} AND author_user=$eddie->{node_id} AND message_id>$before");
    ok($target_msg, 'string-form forwarded correctly');
    $DB->sqlDelete('message', "message_id=$target_msg->{message_id}") if $target_msg;
};

#############################################################################
# Section 3 — messageignore blocks delivery
#############################################################################
subtest 'messageignore: target blocking sender drops message' => sub {
    my $before = max_msg_id();
    my $result = $APP->sendPrivateMessage($eddie, $ignores_cme,
        'should-be-blocked');
    # The send returns 0 success because all recipients failed.
    is($result->{success}, 0, 'send reports no delivery when only recipient blocks');
    my $blocked_msg = $DB->sqlSelectHashref('*', 'message',
        "for_user=$ignores_cme->{user_id} AND author_user=$eddie->{node_id} AND message_id>$before");
    ok(!$blocked_msg, 'no message landed in ignores_cme inbox');
    my $err = join(',', @{$result->{errors} || []});
    like($err, qr/ignoring/i, 'error reports the ignore relationship');
};

#############################################################################
# Section 4 — cool.pm: forwarding + no_coolnotification suppression
#############################################################################
{
    package MockUser4142;
    sub new {
        my ($class, %a) = @_;
        return bless {
            node_id => $a{node_id}, title => $a{title},
            _nodedata => $a{nodedata}, _coolsleft => $a{coolsleft} // 10,
            _guest => $a{guest} // 0,
        }, $class;
    }
    sub is_guest { return shift->{_guest}; }
    sub node_id  { shift->{node_id}; }
    sub title    { shift->{title}; }
    sub NODEDATA { shift->{_nodedata}; }
    sub coolsleft { shift->{_coolsleft}; }
    sub votesleft { 10 }
    sub VARS { shift->{_vars} // {}; }  # _notify_bookmark reads $user->VARS->{no_bookmarkinformer}
    package MockRequest4142;
    sub new   { my ($c, %a) = @_; bless { user => MockUser4142->new(%a) }, $c; }
    sub user  { shift->{user}; }
}

# Helper: cool a fresh writeup as $cooler and return the result hashref.
# Creates a one-shot writeup so "already cooled" doesn't trip us.
sub cool_one {
    my ($author, $cooler_user, $label) = @_;
    my $writeup_type = $DB->getNode('writeup', 'nodetype');
    my $parent_id    = $DB->insertNode("Test e2node for $label", 'e2node', -1);
    my $writeup_id   = $DB->insertNode("Test writeup for $label", $writeup_type, $author, {
        doctext       => "body for $label",
        parent_e2node => $parent_id,
    });
    push @CREATED_NODES, $parent_id, $writeup_id;

    my $api = Everything::API::cool->new();
    my $req = MockRequest4142->new(
        node_id  => $cooler_user->{node_id},
        title    => $cooler_user->{title},
        nodedata => $cooler_user,
        coolsleft => 10,
    );
    my $result = $api->award_cool($req, $writeup_id);

    return ($result, $writeup_id, $parent_id);
}

subtest 'cool.pm: CME message forwards when author has message_forward_to' => sub {
    my $before = max_msg_id();
    my ($result, $wu_id, $parent_id) = cool_one($forward_source, $cooler, 'fwd-cool');
    is($result->[1]->{success}, 1, 'cool succeeded');

    my $target_msg = $DB->sqlSelectHashref('*', 'message',
        "for_user=$forward_target->{user_id} AND author_user=$eddie->{node_id} AND message_id>$before");
    ok($target_msg, 'CME message arrived at forward_target (the #4142 fix)');
    like($target_msg->{msgtext} || '', qr/cooled/, 'looks like a CME cool-notification');

    my $src_count = count_msgs_since($forward_source->{user_id}, $eddie->{node_id}, $before);
    is($src_count, 0, 'no CME copy left in forward_source inbox');

    # cleanup
    $DB->sqlDelete('message', "message_id=$target_msg->{message_id}") if $target_msg;
    $DB->sqlDelete('coolwriteups', "coolwriteups_id=$wu_id");
    $DB->sqlDelete('node', "node_id IN ($wu_id, $parent_id)");
};

subtest 'cool.pm: CME suppressed when author has no_coolnotification' => sub {
    # Set the flag on plain_user
    my $v = $APP->getVars($plain_user);
    $v->{no_coolnotification} = 1;
    Everything::setVars($plain_user, $v);

    my $before = max_msg_id();
    my ($result, $wu_id, $parent_id) = cool_one($plain_user, $cooler, 'suppress-cool');
    is($result->[1]->{success}, 1, 'cool itself succeeded');

    my $count = count_msgs_since($plain_user->{user_id}, $eddie->{node_id}, $before);
    is($count, 0, 'no CME message inserted when author opts out');

    # cleanup
    delete $v->{no_coolnotification};
    Everything::setVars($plain_user, $v);
    $DB->sqlDelete('coolwriteups', "coolwriteups_id=$wu_id");
    $DB->sqlDelete('node', "node_id IN ($wu_id, $parent_id)");
};

subtest 'cool.pm: CME delivered when no opt-out and no forwarding' => sub {
    my $before = max_msg_id();
    my ($result, $wu_id, $parent_id) = cool_one($plain_user, $cooler, 'plain-cool');
    is($result->[1]->{success}, 1, 'cool succeeded');

    my $msg = $DB->sqlSelectHashref('*', 'message',
        "for_user=$plain_user->{user_id} AND author_user=$eddie->{node_id} AND message_id>$before");
    ok($msg, 'CME message landed in plain_user inbox');
    like($msg->{msgtext} || '', qr/cooled/, 'looks like a cool notification');

    # cleanup
    $DB->sqlDelete('message', "message_id=$msg->{message_id}") if $msg;
    $DB->sqlDelete('coolwriteups', "coolwriteups_id=$wu_id");
    $DB->sqlDelete('node', "node_id IN ($wu_id, $parent_id)");
};

subtest 'cool.pm: CME blocked when author ignores Cool Man Eddie' => sub {
    my $before = max_msg_id();
    my ($result, $wu_id, $parent_id) = cool_one($ignores_cme, $cooler, 'ignore-cool');
    is($result->[1]->{success}, 1, 'cool itself succeeded');
    my $count = count_msgs_since($ignores_cme->{user_id}, $eddie->{node_id}, $before);
    is($count, 0, 'CME message dropped because author ignores Eddie');

    # cleanup
    $DB->sqlDelete('coolwriteups', "coolwriteups_id=$wu_id");
    $DB->sqlDelete('node', "node_id IN ($wu_id, $parent_id)");
};

#############################################################################
# Section 5 — cool.pm bookmark CME: forwarding + no_bookmarkinformer + ignore
#
# Same gating structure as award_cool (#4142 follow-up):
#   * no_bookmarkinformer = bookmark-specific opt-out (stays in cool.pm)
#   * message_forward_to / messageignore = sendPrivateMessage's job
#############################################################################

# The writeup nodetype has disable_bookmark set globally on prod and dev.
# Temporarily clear it so toggle_bookmark gets past can_bookmark() in these
# tests. Restored in the END block. Same pattern as t/062.
my $writeup_type_node = $DB->getNode('writeup', 'nodetype');
my $original_disable_bookmark =
    $DB->getNodeParam($writeup_type_node, 'disable_bookmark');
$DB->deleteNodeParam($writeup_type_node, 'disable_bookmark');

# Helper: bookmark a fresh writeup as $bookmarker_user. Returns (api result,
# writeup_id, parent_id). Creates the writeup so we don't trip "already
# bookmarked".
sub bookmark_one {
    my ($author, $bookmarker_user, $label) = @_;
    my $writeup_type = $DB->getNode('writeup', 'nodetype');
    my $parent_id    = $DB->insertNode("Test e2node for bookmark $label", 'e2node', -1);
    my $writeup_id   = $DB->insertNode("Test writeup for bookmark $label", $writeup_type, $author, {
        doctext       => "body for bookmark $label",
        parent_e2node => $parent_id,
    });
    push @CREATED_NODES, $parent_id, $writeup_id;

    my $api = Everything::API::cool->new();
    my $req = MockRequest4142->new(
        node_id  => $bookmarker_user->{node_id},
        title    => $bookmarker_user->{title},
        nodedata => $bookmarker_user,
        coolsleft => 10,
    );
    my $result = $api->toggle_bookmark($req, $writeup_id);
    return ($result, $writeup_id, $parent_id);
}

subtest 'bookmark CME: forwards when author has message_forward_to (#4142)' => sub {
    my $before = max_msg_id();
    my ($result, $wu_id, $parent_id) = bookmark_one($forward_source, $cooler, 'fwd-bookmark');
    is($result->[1]->{success}, 1, 'bookmark succeeded');

    my $target_msg = $DB->sqlSelectHashref('*', 'message',
        "for_user=$forward_target->{user_id} AND author_user=$eddie->{node_id} AND message_id>$before");
    ok($target_msg, 'bookmark CME landed in forward_target inbox');
    like($target_msg->{msgtext} || '', qr/bookmarked/i, 'looks like a bookmark notification');

    my $src_count = count_msgs_since($forward_source->{user_id}, $eddie->{node_id}, $before);
    is($src_count, 0, 'no copy left in forward_source inbox');

    # cleanup
    $DB->sqlDelete('message', "message_id=$target_msg->{message_id}") if $target_msg;
    $DB->sqlDelete('links',
        "from_node=$cooler->{node_id} AND to_node=$wu_id");
    $DB->sqlDelete('node', "node_id IN ($wu_id, $parent_id)");
};

subtest 'bookmark CME: suppressed when author has no_bookmarkinformer' => sub {
    my $v = $APP->getVars($plain_user);
    $v->{no_bookmarknotification} = 1;  # the AUTHOR's opt-out (no_bookmarkinformer is the bookmarker's, cool.pm:331 vs :365)
    Everything::setVars($plain_user, $v);

    my $before = max_msg_id();
    my ($result, $wu_id, $parent_id) = bookmark_one($plain_user, $cooler, 'suppress-bookmark');
    is($result->[1]->{success}, 1, 'bookmark itself succeeded');

    my $count = count_msgs_since($plain_user->{user_id}, $eddie->{node_id}, $before);
    is($count, 0, 'no CME message when author opts out of bookmark notifications');

    # cleanup
    delete $v->{no_bookmarknotification};
    Everything::setVars($plain_user, $v);
    $DB->sqlDelete('links',
        "from_node=$cooler->{node_id} AND to_node=$wu_id");
    $DB->sqlDelete('node', "node_id IN ($wu_id, $parent_id)");
};

subtest 'bookmark CME: delivered when no opt-out and no forwarding' => sub {
    my $before = max_msg_id();
    my ($result, $wu_id, $parent_id) = bookmark_one($plain_user, $cooler, 'plain-bookmark');
    is($result->[1]->{success}, 1, 'bookmark succeeded');

    my $msg = $DB->sqlSelectHashref('*', 'message',
        "for_user=$plain_user->{user_id} AND author_user=$eddie->{node_id} AND message_id>$before");
    ok($msg, 'bookmark CME landed in plain_user inbox');
    like($msg->{msgtext} || '', qr/bookmarked/i, 'looks like a bookmark notification');

    # cleanup
    $DB->sqlDelete('message', "message_id=$msg->{message_id}") if $msg;
    $DB->sqlDelete('links',
        "from_node=$cooler->{node_id} AND to_node=$wu_id");
    $DB->sqlDelete('node', "node_id IN ($wu_id, $parent_id)");
};

subtest 'bookmark CME: blocked when author ignores Cool Man Eddie' => sub {
    my $before = max_msg_id();
    my ($result, $wu_id, $parent_id) = bookmark_one($ignores_cme, $cooler, 'ignore-bookmark');
    is($result->[1]->{success}, 1, 'bookmark itself succeeded');
    my $count = count_msgs_since($ignores_cme->{user_id}, $eddie->{node_id}, $before);
    is($count, 0, 'bookmark CME dropped because author ignores Eddie');

    # cleanup
    $DB->sqlDelete('links',
        "from_node=$cooler->{node_id} AND to_node=$wu_id");
    $DB->sqlDelete('node', "node_id IN ($wu_id, $parent_id)");
};

subtest 'bookmark CME: self-bookmark sends no CME' => sub {
    # cooler bookmarks their own writeup — no notification expected.
    my $before = max_msg_id();
    my ($result, $wu_id, $parent_id) = bookmark_one($cooler, $cooler, 'self-bookmark');
    is($result->[1]->{success}, 1, 'bookmark succeeded');
    my $count = count_msgs_since($cooler->{user_id}, $eddie->{node_id}, $before);
    is($count, 0, 'no CME when bookmarking your own writeup');

    # cleanup
    $DB->sqlDelete('links',
        "from_node=$cooler->{node_id} AND to_node=$wu_id");
    $DB->sqlDelete('node', "node_id IN ($wu_id, $parent_id)");
};

#############################################################################
# Teardown — drop test users + supporting rows
#############################################################################
END {
    # Only run if $DB is still around (i.e. we made it past init).
    return unless $DB;

    # Restore the writeup nodetype's disable_bookmark, if it was set before
    # we wiped it. Skip restore if the var wasn't defined locally (i.e. the
    # bookmark setup block didn't run).
    if (defined $writeup_type_node && $original_disable_bookmark) {
        $DB->setNodeParam($writeup_type_node, 'disable_bookmark',
            $original_disable_bookmark);
    }

    for my $u ($forward_target, $forward_source, $ignores_cme, $plain_user, $cooler) {
        next unless $u && $u->{node_id};
        $DB->sqlDelete('messageignore', "messageignore_id=$u->{node_id} OR ignore_node=$u->{node_id}");
        $DB->sqlDelete('message',  "for_user=$u->{node_id} OR author_user=$u->{node_id}");
        $DB->sqlDelete('uservars', "user_id=$u->{node_id}");
        $DB->sqlDelete('user',     "user_id=$u->{node_id}");
        $DB->sqlDelete('node',     "node_id=$u->{node_id}");
    }
}

done_testing;
