#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions RequireExtendedFormatting RequireLineBoundaryMatching RequireDotMatchAnything)
## no critic (ValuesAndExpressions ProhibitInterpolationOfLiterals ProhibitMagicNumbers)

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;
use Everything::Application;
use Everything::Delegation::notification;

# Initialize Everything
# Note: This may print log permission warnings, which can be ignored in test context
{
	local $SIG{__WARN__} = sub {
		my $warning = shift;
		# Suppress log file permission warnings during tests
		warn $warning unless $warning =~ /Could not open log/;
	};
	initEverything('development-docker');
}

ok($DB, "Database connection established");
ok($APP, "Application object created");

#############################################################################
# Test notification rendering functions
#
# These tests verify that all notification types render correctly with
# various input scenarios. Each notification function should:
# 1. Return a non-empty string
# 2. Handle missing/invalid arguments gracefully
# 3. Produce appropriate output for the notification type
#############################################################################

# Helper function to create mock node for testing
sub mock_node {
    my ($node_id, $title) = @_;
    return {
        node_id => $node_id,
        title => $title,
        type => { title => 'test' }
    };
}

# Helper function to test basic notification output
sub test_notification {
    my ($name, $func, $args, $expected_pattern, $description) = @_;

    my $result = $func->($DB, $APP, $args);
    ok(defined $result, "$name: Returns defined value - $description");
    ok(length($result) > 0, "$name: Returns non-empty string - $description");

    if ($expected_pattern) {
        like($result, $expected_pattern, "$name: Contains expected text - $description");
    }

    return $result;
}

#############################################################################
# Test: achievement notification
#############################################################################

{
    my $achievement = getNode("Paragon of Creativity", "achievement");
    SKIP: {
        skip "Paragon of Creativity achievement not found", 3 unless $achievement;

        my $args = { achievement_id => $achievement->{node_id} };
        test_notification(
            'achievement',
            \&Everything::Delegation::notification::achievement,
            $args,
            qr/earned.*achievement/i,
            'with valid achievement'
        );
    }

    # Test with missing achievement_id
    my $result = Everything::Delegation::notification::achievement($DB, $APP, {});
    ok(defined $result, "achievement: Handles missing achievement_id");
}

#############################################################################
# Test: voting notification
#############################################################################

{
    # Test upvote
    my $args = { node_id => 123, weight => 1, amount => 1 };
    test_notification(
        'voting',
        \&Everything::Delegation::notification::voting,
        $args,
        qr/upvoted/i,
        'upvote with node_id'
    );

    # Test downvote
    $args = { node_id => 456, weight => -1, amount => -2 };
    test_notification(
        'voting',
        \&Everything::Delegation::notification::voting,
        $args,
        qr/downvoted/i,
        'downvote with node_id'
    );

    # Test without node_id
    $args = { weight => 1, amount => 1 };
    my $result = Everything::Delegation::notification::voting($DB, $APP, $args);
    ok(defined $result, "voting: Handles missing node_id");
    like($result, qr/upvoted/i, "voting: Upvote text without node_id");
}

#############################################################################
# Test: newcomment notification
#############################################################################

{
    my $args = { node_id => 789, comment_id => 101 };
    test_notification(
        'newcomment',
        \&Everything::Delegation::notification::newcomment,
        $args,
        qr/commented/i,
        'with node_id and comment_id'
    );

    # Test without node_id
    $args = { comment_id => 101 };
    my $result = Everything::Delegation::notification::newcomment($DB, $APP, $args);
    ok(defined $result, "newcomment: Handles missing node_id");
}

#############################################################################
# Test: experience notification
#############################################################################

{
    # Test XP gain (singular)
    my $args = { amount => 1 };
    test_notification(
        'experience',
        \&Everything::Delegation::notification::experience,
        $args,
        qr/gained 1 experience point$/,
        'gain 1 XP (singular)'
    );

    # Test XP gain (plural)
    $args = { amount => 5 };
    test_notification(
        'experience',
        \&Everything::Delegation::notification::experience,
        $args,
        qr/gained 5 experience points$/,
        'gain 5 XP (plural)'
    );

    # Test XP loss (singular)
    $args = { amount => -1 };
    test_notification(
        'experience',
        \&Everything::Delegation::notification::experience,
        $args,
        qr/lost 1 experience point$/,
        'lose 1 XP (singular)'
    );

    # Test XP loss (plural)
    $args = { amount => -3 };
    test_notification(
        'experience',
        \&Everything::Delegation::notification::experience,
        $args,
        qr/lost 3 experience points$/,
        'lose 3 XP (plural)'
    );

    # Test zero XP change
    $args = { amount => 0 };
    test_notification(
        'experience',
        \&Everything::Delegation::notification::experience,
        $args,
        qr/changed/i,
        'zero XP change'
    );

    # Test missing amount
    my $result = Everything::Delegation::notification::experience($DB, $APP, {});
    ok(defined $result, "experience: Handles missing amount");
}

#############################################################################
# Test: GP notification
#############################################################################

{
    # Test single GP
    my $args = { amount => 1 };
    test_notification(
        'gp',
        \&Everything::Delegation::notification::gp,
        $args,
        qr/received 1 GP$/,
        'receive 1 GP (singular)'
    );

    # Test multiple GP
    $args = { amount => 3 };
    test_notification(
        'gp',
        \&Everything::Delegation::notification::gp,
        $args,
        qr/received 3 GPs$/,
        'receive 3 GPs (plural)'
    );

    # Test missing amount (should default to 1)
    my $result = Everything::Delegation::notification::gp($DB, $APP, {});
    ok(defined $result, "gp: Handles missing amount");
    like($result, qr/received 1 GP$/, "gp: Defaults to 1 GP");
}

#############################################################################
# Test: cooled notification
#############################################################################

{
    my $args = { writeup_id => 123, cooluser_id => 888 };
    test_notification(
        'cooled',
        \&Everything::Delegation::notification::cooled,
        $args,
        qr/cooled/i,
        'with writeup_id'
    );

    # Test without writeup_id
    my $result = Everything::Delegation::notification::cooled($DB, $APP, {});
    ok(defined $result, "cooled: Handles missing writeup_id");
}

#############################################################################
# Test: frontpage notification
#############################################################################

{
    my $args = { frontpage_item_id => 456 };
    test_notification(
        'frontpage',
        \&Everything::Delegation::notification::frontpage,
        $args,
        qr/front page/i,
        'with frontpage_item_id'
    );

    # Test without frontpage_item_id
    my $result = Everything::Delegation::notification::frontpage($DB, $APP, {});
    ok(defined $result, "frontpage: Handles missing frontpage_item_id");
}

#############################################################################
# Test: favorite notification
#############################################################################

{
    my $args = { node_id => 789 };
    test_notification(
        'favorite',
        \&Everything::Delegation::notification::favorite,
        $args,
        qr/favorited/i,
        'with node_id'
    );

    # Test without node_id
    my $result = Everything::Delegation::notification::favorite($DB, $APP, {});
    ok(defined $result, "favorite: Handles missing node_id");
}

#############################################################################
# Test: bookmark notification
#############################################################################

{
    my $args = { writeup_id => 101, bookmark_user => 999, nodeshell => 0 };
    test_notification(
        'bookmark',
        \&Everything::Delegation::notification::bookmark,
        $args,
        qr/bookmarked/i,
        'with writeup_id'
    );

    # Test without writeup_id
    my $result = Everything::Delegation::notification::bookmark($DB, $APP, {});
    ok(defined $result, "bookmark: Handles missing writeup_id");
}

#############################################################################
# Test: mostwanted notification
#############################################################################

{
    my $args = { node_id => 202 };
    test_notification(
        'mostwanted',
        \&Everything::Delegation::notification::mostwanted,
        $args,
        qr/Most Wanted/i,
        'with node_id'
    );

    # Test without node_id
    my $result = Everything::Delegation::notification::mostwanted($DB, $APP, {});
    ok(defined $result, "mostwanted: Handles missing node_id");
}

#############################################################################
# Test: draft_for_review notification
#############################################################################

{
    my $args = { node_id => 303 };
    test_notification(
        'draft_for_review',
        \&Everything::Delegation::notification::draft_for_review,
        $args,
        qr/draft.*review/i,
        'with node_id'
    );

    # Test without node_id
    my $result = Everything::Delegation::notification::draft_for_review($DB, $APP, {});
    ok(defined $result, "draft_for_review: Handles missing node_id");
}

#############################################################################
# Test: writeupedit notification
#############################################################################

{
    my $args = { node_id => 404, author => 'testuser' };
    test_notification(
        'writeupedit',
        \&Everything::Delegation::notification::writeupedit,
        $args,
        qr/edited/i,
        'with node_id and author'
    );

    # Test without author
    $args = { node_id => 404 };
    my $result = Everything::Delegation::notification::writeupedit($DB, $APP, $args);
    ok(defined $result, "writeupedit: Handles missing author");
    like($result, qr/edited/i, "writeupedit: Contains 'edited'");

    # Test without node_id
    $args = { author => 'testuser' };
    $result = Everything::Delegation::notification::writeupedit($DB, $APP, $args);
    ok(defined $result, "writeupedit: Handles missing node_id");
}

#############################################################################
# Test: editor_removed_writeup notification
#############################################################################

{
    my $args = { node_id => 505, title => 'Test Writeup', author => 'testuser' };
    test_notification(
        'editor_removed_writeup',
        \&Everything::Delegation::notification::editor_removed_writeup,
        $args,
        qr/editor removed/i,
        'with all fields'
    );

    # Test without title
    $args = { node_id => 505 };
    my $result = Everything::Delegation::notification::editor_removed_writeup($DB, $APP, $args);
    ok(defined $result, "editor_removed_writeup: Handles missing title");
    like($result, qr/your writeup/i, "editor_removed_writeup: Uses default title");
}

#############################################################################
# Test: author_removed_writeup notification
#############################################################################

{
    my $args = { node_id => 606, title => 'My Writeup' };
    test_notification(
        'author_removed_writeup',
        \&Everything::Delegation::notification::author_removed_writeup,
        $args,
        qr/You removed/i,
        'with title'
    );

    # Test without title
    my $result = Everything::Delegation::notification::author_removed_writeup($DB, $APP, {});
    ok(defined $result, "author_removed_writeup: Handles missing title");
    like($result, qr/your writeup/i, "author_removed_writeup: Uses default title");
}

#############################################################################
# Test: blankedwriteup notification
#############################################################################

{
    my $args = { node_id => 707, title => 'Blanked Content' };
    test_notification(
        'blankedwriteup',
        \&Everything::Delegation::notification::blankedwriteup,
        $args,
        qr/was blanked/i,
        'with title'
    );

    # Test without title
    my $result = Everything::Delegation::notification::blankedwriteup($DB, $APP, {});
    ok(defined $result, "blankedwriteup: Handles missing title");
    like($result, qr/A writeup/i, "blankedwriteup: Uses default title");
}

#############################################################################
# Test: nodenote notification
#############################################################################

{
    my $args = { node_id => 808, note => 'Test note content' };
    test_notification(
        'nodenote',
        \&Everything::Delegation::notification::nodenote,
        $args,
        qr/Node note/i,
        'with node_id and note'
    );

    # Test without note
    $args = { node_id => 808 };
    my $result = Everything::Delegation::notification::nodenote($DB, $APP, $args);
    ok(defined $result, "nodenote: Handles missing note");

    # Test without node_id
    $args = { note => 'Test note' };
    $result = Everything::Delegation::notification::nodenote($DB, $APP, $args);
    ok(defined $result, "nodenote: Handles missing node_id");
}

#############################################################################
# Test: newbiewriteup notification
#############################################################################

{
    my $args = { node_id => 909, author => 'newuser' };
    test_notification(
        'newbiewriteup',
        \&Everything::Delegation::notification::newbiewriteup,
        $args,
        qr/New user.*first writeup/i,
        'with node_id and author'
    );

    # Test without author
    $args = { node_id => 909 };
    my $result = Everything::Delegation::notification::newbiewriteup($DB, $APP, $args);
    ok(defined $result, "newbiewriteup: Handles missing author");

    # Test without node_id
    $args = { author => 'newuser' };
    $result = Everything::Delegation::notification::newbiewriteup($DB, $APP, $args);
    ok(defined $result, "newbiewriteup: Handles missing node_id");
}

#############################################################################
# Test: newdiscussion notification
#############################################################################

{
    my $args = { node_id => 1010 };
    test_notification(
        'newdiscussion',
        \&Everything::Delegation::notification::newdiscussion,
        $args,
        qr/discussion/i,
        'with node_id'
    );

    # Test without node_id
    my $result = Everything::Delegation::notification::newdiscussion($DB, $APP, {});
    ok(defined $result, "newdiscussion: Handles missing node_id");
}

#############################################################################
# Test: e2poll notification
#############################################################################

{
    my $args = { node_id => 1111 };
    test_notification(
        'e2poll',
        \&Everything::Delegation::notification::e2poll,
        $args,
        qr/poll/i,
        'with node_id'
    );

    # Test without node_id
    my $result = Everything::Delegation::notification::e2poll($DB, $APP, {});
    ok(defined $result, "e2poll: Handles missing node_id");
}

#############################################################################
# Test: weblog notification
#############################################################################

{
    my $args = { writeup_id => 1212, group_id => 567 };
    test_notification(
        'weblog',
        \&Everything::Delegation::notification::weblog,
        $args,
        qr/weblog/i,
        'with writeup_id'
    );

    # Test without writeup_id
    my $result = Everything::Delegation::notification::weblog($DB, $APP, {});
    ok(defined $result, "weblog: Handles missing writeup_id");
}

#############################################################################
# Test: socialbookmark notification
#############################################################################

{
    my $args = { writeup_id => 1313, bookmark_user => 777, bookmark_site => 'Twitter' };
    test_notification(
        'socialbookmark',
        \&Everything::Delegation::notification::socialbookmark,
        $args,
        qr/shared/i,
        'with writeup_id and bookmark_site'
    );

    # Test without bookmark_site
    $args = { writeup_id => 1313, bookmark_user => 777 };
    my $result = Everything::Delegation::notification::socialbookmark($DB, $APP, $args);
    ok(defined $result, "socialbookmark: Handles missing bookmark_site");
    like($result, qr/shared/i, "socialbookmark: Contains 'shared'");

    # Test without writeup_id
    $args = { bookmark_site => 'Twitter', bookmark_user => 777 };
    $result = Everything::Delegation::notification::socialbookmark($DB, $APP, $args);
    ok(defined $result, "socialbookmark: Handles missing writeup_id");
}

#############################################################################
# Test: chanop_borged_user notification
#############################################################################

{
    my $args = { user_id => 1414 };
    test_notification(
        'chanop_borged_user',
        \&Everything::Delegation::notification::chanop_borged_user,
        $args,
        qr/borged/i,
        'with user_id'
    );

    # Test without user_id
    my $result = Everything::Delegation::notification::chanop_borged_user($DB, $APP, {});
    ok(defined $result, "chanop_borged_user: Handles missing user_id");
}

#############################################################################
# Test: chanop_dragged_user notification
#############################################################################

{
    my $args = { user_id => 1515 };
    test_notification(
        'chanop_dragged_user',
        \&Everything::Delegation::notification::chanop_dragged_user,
        $args,
        qr/dragged/i,
        'with user_id'
    );

    # Test without user_id
    my $result = Everything::Delegation::notification::chanop_dragged_user($DB, $APP, {});
    ok(defined $result, "chanop_dragged_user: Handles missing user_id");
}

#############################################################################
# Summary test: Verify all notification functions exist
#############################################################################

{
    my @notification_types = qw(
        achievement voting newcomment experience gp cooled frontpage
        favorite bookmark mostwanted draft_for_review writeupedit
        editor_removed_writeup author_removed_writeup blankedwriteup
        nodenote newbiewriteup newdiscussion e2poll weblog socialbookmark
        chanop_borged_user chanop_dragged_user
    );

    foreach my $type (@notification_types) {
        my $func = "Everything::Delegation::notification::$type";
        ok(Everything::Delegation::notification->can($type),
           "Notification function '$type' exists and is callable");
    }
}

done_testing();
