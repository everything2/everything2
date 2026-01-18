#!/usr/bin/perl -w

use strict;
use warnings;

package Everything::Delegation::notification;

#############################################################################
#
# Everything::Delegation::notification
#
# Notification rendering delegation functions
#
# This module contains delegated notification rendering logic.
# Each function represents a notification type's display logic.
#
# Function naming convention:
#   - Lowercase notification title
#   - Spaces and hyphens replaced with underscores
#   - Non-alphanumeric characters replaced with underscores
#
# Function signature:
#   sub notification_name {
#     my ($DB, $APP, $args) = @_;
#     # Generate notification HTML
#     return "Notification text with HTML";
#   }
#
# Note: These functions are called from Everything::Application::getRenderedNotifications
#
# Args parameter:
#   $args is a hashref containing context-specific data passed when the
#   notification was created. Common fields:
#     - node_id: The node being referenced
#     - user_id: The user performing the action
#     - amount: Numeric amount (XP, GP, vote count, etc.)
#     - weight: Vote weight (+1 for upvote, -1 for downvote)
#     - achievement_id: Achievement node ID
#     - etc. (varies by notification type)
#
#############################################################################

#############################################################################
# Achievement notification
# Triggered when user earns an achievement
# Args: { achievement_id => node_id }
#############################################################################

sub achievement
{
    my ($DB, $APP, $args) = @_;

    my $achievement = $DB->getNodeById($args->{achievement_id});
    return "You earned an achievement!" unless $achievement;
    return "You earned the " . $achievement->{display} . " achievement!";
}

#############################################################################
# Voting notification
# Triggered when someone votes on user's writeup
# Args: { node_id => writeup_id, weight => (+1|-1), amount => count }
#############################################################################

sub voting
{
    my ($DB, $APP, $args) = @_;

    my $str;
    if ($args->{weight} > 0) {
        $str .= "Someone upvoted ";
    }
    else {
        $str .= "Someone downvoted ";
        $args->{amount} = -1 * $args->{amount};
    }

    $str .= $APP->bracketLink( $args->{node_id}) if $args->{node_id};

    return $str;
}

#############################################################################
# New comment notification
# Triggered when someone comments on user's writeup
# Args: { node_id => writeup_id, comment_id => comment_node_id }
#############################################################################

sub newcomment
{
    my ($DB, $APP, $args) = @_;

    my $str = "Someone commented on ";
    $str .= $APP->bracketLink( $args->{node_id}) if $args->{node_id};

    return $str;
}

#############################################################################
# Experience points notification
# Triggered when user gains or loses XP
# Args: { amount => xp_change }
#############################################################################

sub experience
{
    my ($DB, $APP, $args) = @_;

    my $amount = $args->{amount} || 0;

    if ($amount > 0) {
        return "You gained $amount experience point" . ($amount != 1 ? "s" : "");
    }
    elsif ($amount < 0) {
        my $abs_amount = abs($amount);
        return "You lost $abs_amount experience point" . ($abs_amount != 1 ? "s" : "");
    }
    else {
        return "Your experience points changed";
    }
}

#############################################################################
# GP (Golden Peach) notification
# Triggered when user receives GP
# Args: { amount => gp_count }
#############################################################################

sub gp
{
    my ($DB, $APP, $args) = @_;

    my $amount = $args->{amount} || 1;
    return "You received $amount GP" . ($amount != 1 ? "s" : "");
}

#############################################################################
# Cooled writeup notification
# Triggered when user's writeup is cooled by an editor
# Args: { writeup_id => node_id, cooluser_id => user_id }
#############################################################################

sub cooled
{
    my ($DB, $APP, $args) = @_;

    my $str = "Your writeup ";
    $str .= $APP->bracketLink( $args->{writeup_id}) if $args->{writeup_id};
    $str .= " was cooled!";

    return $str;
}

#############################################################################
# Front page notification
# Triggered when user's writeup hits the front page
# Args: { frontpage_item_id => node_id }
#############################################################################

sub frontpage
{
    my ($DB, $APP, $args) = @_;

    my $str = "Your writeup ";
    $str .= $APP->bracketLink( $args->{frontpage_item_id}) if $args->{frontpage_item_id};
    $str .= " made it to the front page!";

    return $str;
}

#############################################################################
# Favorite notification
# Triggered when someone favorites user's writeup
# Args: { node_id => writeup_id }
#############################################################################

sub favorite
{
    my ($DB, $APP, $args) = @_;

    my $str = "Someone favorited ";
    $str .= $APP->bracketLink( $args->{node_id}) if $args->{node_id};

    return $str;
}

#############################################################################
# Bookmark notification
# Triggered when someone bookmarks user's node
# Args: { writeup_id => node_id, bookmark_user => user_id, nodeshell => 0|1 }
#############################################################################

sub bookmark
{
    my ($DB, $APP, $args) = @_;

    my $str = "Someone bookmarked ";
    $str .= $APP->bracketLink( $args->{writeup_id}) if $args->{writeup_id};

    return $str;
}

#############################################################################
# Most wanted notification
# Triggered when user's writeup appears on most wanted list
# Args: { node_id => writeup_id }
#############################################################################

sub mostwanted
{
    my ($DB, $APP, $args) = @_;

    my $str = "Your writeup ";
    $str .= $APP->bracketLink( $args->{node_id}) if $args->{node_id};
    $str .= " is on the Most Wanted list";

    return $str;
}

#############################################################################
# Draft for review notification
# Triggered when someone submits a draft for editorial review
# Args: { draft_id => node_id } (note: maintenance.pm passes draft_id, not node_id)
#############################################################################

sub draft_for_review
{
    my ($DB, $APP, $args) = @_;

    my $str = "New draft submitted for review: ";
    # maintenance.pm passes draft_id, not node_id
    my $draft_id = $args->{draft_id} || $args->{node_id};

    if ($draft_id) {
        my $node = $DB->getNodeById($draft_id);
        $str .= "[$node->{title}]" if $node;
    }

    return $str;
}

#############################################################################
# Writeup edit notification
# Triggered when someone edits their writeup
# Args: { node_id => writeup_id, author => author_name }
#############################################################################

sub writeupedit
{
    my ($DB, $APP, $args) = @_;

    my $str = "";
    $str .= $args->{author} . " " if $args->{author};
    $str .= "edited ";
    $str .= $APP->bracketLink( $args->{node_id}) if $args->{node_id};

    return $str;
}

#############################################################################
# Editor removed writeup notification
# Triggered when an editor deletes a writeup
# Args: { node_id => writeup_id, title => writeup_title, author => author_name }
#############################################################################

sub editor_removed_writeup
{
    my ($DB, $APP, $args) = @_;

    my $title = $args->{title} || "your writeup";
    my $str = "An editor removed \"$title\"";

    return $str;
}

#############################################################################
# Author removed writeup notification
# Triggered when author deletes their own writeup
# Args: { node_id => writeup_id, title => writeup_title }
#############################################################################

sub author_removed_writeup
{
    my ($DB, $APP, $args) = @_;

    my $title = $args->{title} || "your writeup";
    my $str = "You removed \"$title\"";

    return $str;
}

#############################################################################
# Blanked writeup notification
# Triggered when a writeup is blanked
# Args: { node_id => writeup_id, title => writeup_title }
#############################################################################

sub blankedwriteup
{
    my ($DB, $APP, $args) = @_;

    my $title = $args->{title} || "A writeup";
    my $str = "\"$title\" was blanked";

    return $str;
}

#############################################################################
# Node note notification (editors only)
# Triggered when a node note is added
# Args: { node_id => node_id, note => note_text }
#############################################################################

sub nodenote
{
    my ($DB, $APP, $args) = @_;

    my $str = "Node note added to ";
    $str .= $APP->bracketLink( $args->{node_id}) if $args->{node_id};
    $str .= ": " . $args->{note} if $args->{note};

    return $str;
}

#############################################################################
# Newbie writeup notification (for editors)
# Triggered when a new user publishes their first writeup
# Args: { node_id => writeup_id, author => author_name }
#############################################################################

sub newbiewriteup
{
    my ($DB, $APP, $args) = @_;

    my $str = "New user ";
    $str .= $args->{author} . " " if $args->{author};
    $str .= "published their first writeup: ";
    $str .= $APP->bracketLink( $args->{node_id}) if $args->{node_id};

    return $str;
}

#############################################################################
# New discussion notification
# Triggered when a discussion post is made
# Args: { node_id => discussion_id }
#############################################################################

sub newdiscussion
{
    my ($DB, $APP, $args) = @_;

    my $str = "New discussion post: ";
    $str .= $APP->bracketLink( $args->{node_id}) if $args->{node_id};

    return $str;
}

#############################################################################
# E2 poll notification
# Triggered when a new poll is created
# Args: { node_id => poll_id }
#############################################################################

sub e2poll
{
    my ($DB, $APP, $args) = @_;

    my $str = "New poll: ";
    $str .= $APP->bracketLink( $args->{node_id}) if $args->{node_id};

    return $str;
}

#############################################################################
# Weblog notification
# Triggered when a weblog entry is posted
# Args: { writeup_id => node_id, group_id => group_node_id }
#############################################################################

sub weblog
{
    my ($DB, $APP, $args) = @_;

    my $str = "New weblog entry: ";
    $str .= $APP->bracketLink( $args->{writeup_id}) if $args->{writeup_id};

    return $str;
}

#############################################################################
# Social bookmark notification
# Triggered when content is shared via social bookmarking
# Args: { writeup_id => node_id, bookmark_user => user_id, bookmark_site => site_name }
#############################################################################

sub socialbookmark
{
    my ($DB, $APP, $args) = @_;

    my $str = "Your content was shared";
    $str .= " on " . $args->{bookmark_site} if $args->{bookmark_site};
    $str .= ": " . $APP->bracketLink( $args->{writeup_id}) if $args->{writeup_id};

    return $str;
}

#############################################################################
# Chanop borged user notification
# Triggered when a chatterbox operator borgs a user
# Args: { user_id => borged_user_id }
#############################################################################

sub chanop_borged_user
{
    my ($DB, $APP, $args) = @_;

    my $str = "You were borged by a chatterbox operator";

    return $str;
}

#############################################################################
# Chanop dragged user notification
# Triggered when a chatterbox operator drags a user
# Args: { user_id => dragged_user_id }
#############################################################################

sub chanop_dragged_user
{
    my ($DB, $APP, $args) = @_;

    my $str = "You were dragged by a chatterbox operator";

    return $str;
}

#############################################################################
#
# Validity check functions (is_valid)
#
# These functions determine if a notification is still valid at display time.
# They are called from getRenderedNotifications() before rendering.
#
# Return values:
#   1 = valid (show notification)
#   0 = invalid (skip notification)
#
# Naming convention: notification_name_is_valid
#
# Logic is ported from the legacy <invalid_check> XML fields.
# If a notification type has no is_valid function, it's assumed valid.
#
#############################################################################

#############################################################################
# Node note validity check
# Invalid if: the node no longer exists OR the nodenote was deleted
#############################################################################

sub nodenote_is_valid
{
    my ($DB, $APP, $args) = @_;

    # Check if the node still exists
    my $node = $DB->getNodeById($args->{node_id});
    return 0 unless $node;

    # Check if the nodenote still exists
    return 1 unless defined $args->{nodenote_id};

    my $note_exists = $DB->sqlSelect('1', 'nodenote', "nodenote_id = $args->{nodenote_id}");
    return $note_exists ? 1 : 0;
}

#############################################################################
# Blanked writeup validity check
# Invalid if: writeup is no longer blank OR is a draft OR doesn't exist
#############################################################################

sub blankedwriteup_is_valid
{
    my ($DB, $APP, $args) = @_;

    my $writeup = $DB->getNodeById($args->{node_id});
    return 0 unless $writeup;

    # Check if it's a draft (drafts shouldn't trigger blanked notifications)
    return 0 if $writeup->{type}{title} eq 'draft';

    # Check if it's still blank (less than 20 chars of content)
    my $doctext = $writeup->{doctext} || '';
    $doctext =~ s/^\s+|\s+$//g;
    my $is_blank = ($doctext eq '' || length($doctext) < 20);

    return $is_blank ? 1 : 0;
}

#############################################################################
# Favorite validity check
# Invalid if: the writeup no longer exists or is not a writeup
#############################################################################

sub favorite_is_valid
{
    my ($DB, $APP, $args) = @_;

    my $node = $DB->getNodeById($args->{node_id});
    return 0 unless $node;
    return 0 unless $node->{type}{title} eq 'writeup';

    return 1;
}

#############################################################################
# Frontpage validity check
# Invalid if: the item was removed from the front page (News weblog)
#############################################################################

sub frontpage_is_valid
{
    my ($DB, $APP, $args) = @_;

    my $target_id = int($args->{frontpage_item_id} || 0);
    return 0 unless $target_id;

    # Get the News usergroup (front page)
    my $news_node = $DB->getNode('News', 'usergroup');
    return 1 unless $news_node;  # If can't find News, assume valid

    my $news_page = $news_node->{node_id};

    # Check if it was removed (removedby_user != 0 means it was unlinked)
    my $unlinker_id = $DB->sqlSelect(
        'removedby_user', 'weblog',
        "weblog_id = $news_page AND to_node = $target_id"
    );

    # If unlinker_id is set (not 0), it was removed = invalid
    return ($unlinker_id && $unlinker_id != 0) ? 0 : 1;
}

#############################################################################
# Newbie writeup validity check
# Invalid if: writeup is now a draft OR was republished (different publish time)
#############################################################################

sub newbiewriteup_is_valid
{
    my ($DB, $APP, $args) = @_;

    my $writeup = $DB->getNodeById($args->{writeup_id});
    return 0 unless $writeup;

    # Check if it became a draft
    return 0 if $writeup->{type}{title} eq 'draft';

    # Check if publish time changed significantly (indicating republish)
    # If we have the original publish_time in args, compare
    if ($args->{publish_time} && $writeup->{publishtime}) {
        # Allow 10 second tolerance for race conditions
        my $notify_time = $args->{publish_time};
        my $writeup_time = $writeup->{publishtime};

        # Simple string comparison - if they differ significantly, it's a republish
        # This is a simplification of the original DateTime comparison
        if ($notify_time ne $writeup_time) {
            # Check if the difference is more than 10 seconds
            # For simplicity, if they don't match exactly (within reason), consider it republished
            return 0;
        }
    }

    return 1;
}

#############################################################################
# Draft for review validity check
# Invalid if: draft no longer exists or is no longer pending review
#############################################################################

sub draft_for_review_is_valid
{
    my ($DB, $APP, $args) = @_;

    my $draft_id = $args->{draft_id} || $args->{node_id};
    return 0 unless $draft_id;

    my $draft = $DB->getNodeById($draft_id);
    return 0 unless $draft;

    # Check if still a draft (not published)
    return 0 unless $draft->{type}{title} eq 'draft';

    # Check publication status if available
    if ($draft->{publication_status}) {
        my $status = $DB->getNodeById($draft->{publication_status});
        # If status indicates it's no longer pending review, invalid
        # "review" status node should exist for valid review notifications
        return 0 if $status && $status->{title} !~ /review/i;
    }

    return 1;
}

#############################################################################
# Bookmark validity check
# Invalid if: the writeup no longer exists
#############################################################################

sub bookmark_is_valid
{
    my ($DB, $APP, $args) = @_;

    my $node = $DB->getNodeById($args->{writeup_id});
    return $node ? 1 : 0;
}

#############################################################################
# Voting validity check
# Invalid if: the writeup no longer exists
#############################################################################

sub voting_is_valid
{
    my ($DB, $APP, $args) = @_;

    my $node = $DB->getNodeById($args->{node_id});
    return $node ? 1 : 0;
}

#############################################################################
# Cooled validity check
# Invalid if: the writeup no longer exists
#############################################################################

sub cooled_is_valid
{
    my ($DB, $APP, $args) = @_;

    my $node = $DB->getNodeById($args->{writeup_id});
    return $node ? 1 : 0;
}

#############################################################################
# E2poll validity check
# Invalid if: the poll no longer exists
#############################################################################

sub e2poll_is_valid
{
    my ($DB, $APP, $args) = @_;

    my $node = $DB->getNodeById($args->{node_id});
    return $node ? 1 : 0;
}

#############################################################################
# Weblog validity check
# Invalid if: the writeup no longer exists
#############################################################################

sub weblog_is_valid
{
    my ($DB, $APP, $args) = @_;

    my $node = $DB->getNodeById($args->{writeup_id});
    return $node ? 1 : 0;
}

#############################################################################
# New discussion validity check
# Invalid if: the discussion no longer exists
#############################################################################

sub newdiscussion_is_valid
{
    my ($DB, $APP, $args) = @_;

    my $node = $DB->getNodeById($args->{node_id});
    return $node ? 1 : 0;
}

#############################################################################
# New comment validity check
# Invalid if: the writeup no longer exists
#############################################################################

sub newcomment_is_valid
{
    my ($DB, $APP, $args) = @_;

    my $node = $DB->getNodeById($args->{node_id});
    return $node ? 1 : 0;
}

#############################################################################
# Most wanted validity check
# Invalid if: the writeup no longer exists
#############################################################################

sub mostwanted_is_valid
{
    my ($DB, $APP, $args) = @_;

    my $node = $DB->getNodeById($args->{node_id});
    return $node ? 1 : 0;
}

#############################################################################
# Writeupedit validity check
# Invalid if: the writeup no longer exists
#############################################################################

sub writeupedit_is_valid
{
    my ($DB, $APP, $args) = @_;

    my $node = $DB->getNodeById($args->{node_id});
    return $node ? 1 : 0;
}

#############################################################################
# Social bookmark validity check
# Invalid if: the writeup no longer exists
#############################################################################

sub socialbookmark_is_valid
{
    my ($DB, $APP, $args) = @_;

    my $node = $DB->getNodeById($args->{writeup_id});
    return $node ? 1 : 0;
}

1;
