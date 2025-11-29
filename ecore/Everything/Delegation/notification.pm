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

1;
