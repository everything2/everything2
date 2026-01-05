#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;
use Everything::Application;
use Everything::API::vote;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

my $api = Everything::API::vote->new();
ok($api, "Created vote API instance");

#############################################################################
# Test Setup: Get real users and create test writeup
#############################################################################

# Get test users - these exist in seeds.pl
my $voter_user_hash = $DB->getNode("normaluser1", "user");
ok($voter_user_hash, "Got voter user (normaluser1)");

my $author_user_hash = $DB->getNode("normaluser2", "user");
ok($author_user_hash, "Got author user (normaluser2)");

my $guest_user_hash = $DB->getNode("guest user", "user");
ok($guest_user_hash, "Got guest user");

# Ensure voter has votes available - always restore to known value
$DB->sqlUpdate('user', { votesleft => 50 }, "user_id=" . $voter_user_hash->{user_id});
# Use direct SQL select to avoid cache issues
my $votes_left = $DB->sqlSelect('votesleft', 'user', "user_id=" . $voter_user_hash->{user_id});
$voter_user_hash->{votesleft} = $votes_left;  # Update hash manually
ok($votes_left >= 5, "Voter has sufficient votes available: $votes_left");

# Create test writeup
my $e2node_title = "Test Vote API Node " . time();
my $e2node_id = $DB->insertNode(
  $e2node_title,
  'e2node',
  $author_user_hash,
  { title => $e2node_title }
);
ok($e2node_id, "Created test e2node");

my $writeup_id = $DB->insertNode(
  $e2node_title,
  'writeup',
  $author_user_hash,
  {
    parent_e2node => $e2node_id,
    doctext => "Test writeup for vote API testing."
  }
);
ok($writeup_id, "Created test writeup");

# Clean up any existing votes on this writeup from previous test runs
$DB->sqlDelete('vote', "vote_id=$writeup_id");

# Simple mock request and user wrapper for testing
# The API expects blessed user objects with methods, but insertVote needs hashrefs
package TestUser;
sub new {
  my ($class, $user_hash) = @_;
  return bless { _hash => $user_hash }, $class;
}
sub is_guest { return shift->{_hash}{title} eq 'Guest User'; }
sub node_id { return shift->{_hash}{user_id}; }
sub votesleft { return shift->{_hash}{votesleft}; }
sub NODEDATA { return shift->{_hash}; }

package TestRequest;
sub new {
  my ($class, $user_hash, $postdata) = @_;
  return bless { user => TestUser->new($user_hash), postdata => $postdata }, $class;
}
sub user { return shift->{user}; }
sub JSON_POSTDATA { return shift->{postdata}; }

package main;

#############################################################################
# Test 1: Guest user cannot vote
#############################################################################

my $guest_request = TestRequest->new($guest_user_hash, { weight => 1 });
my $result = $api->cast_vote($guest_request, $writeup_id);
is($result->[0], 200, "Guest vote returns HTTP 200");
is($result->[1]{success}, 0, "Guest vote fails");
is($result->[1]{error}, 'You must be logged in to vote', "Correct error for guest user");

#############################################################################
# Test 2: Missing writeup_id
#############################################################################

my $voter_request = TestRequest->new($voter_user_hash, { weight => 1 });
$result = $api->cast_vote($voter_request, undef);
is($result->[0], 200, "Missing writeup_id returns HTTP 200");
is($result->[1]{success}, 0, "Missing writeup_id fails");
is($result->[1]{error}, 'Missing or invalid writeup_id', "Correct error for missing writeup_id");

#############################################################################
# Test 3: Invalid writeup_id (non-existent)
#############################################################################

$result = $api->cast_vote($voter_request, 999999999);
is($result->[0], 200, "Invalid writeup_id returns HTTP 200");
is($result->[1]{success}, 0, "Invalid writeup_id fails");
is($result->[1]{error}, 'Writeup not found', "Correct error for non-existent writeup");

#############################################################################
# Test 4: Invalid weight (not 1 or -1)
#############################################################################

$voter_request = TestRequest->new($voter_user_hash, { weight => 0 });
$result = $api->cast_vote($voter_request, $writeup_id);
is($result->[0], 200, "Invalid weight (0) returns HTTP 200");
is($result->[1]{success}, 0, "Invalid weight fails");
is($result->[1]{error}, 'Vote weight must be 1 (upvote) or -1 (downvote)', "Correct error for invalid weight");

$voter_request = TestRequest->new($voter_user_hash, { weight => 2 });
$result = $api->cast_vote($voter_request, $writeup_id);
is($result->[0], 200, "Invalid weight (2) returns HTTP 200");
is($result->[1]{success}, 0, "Invalid weight fails");

#############################################################################
# Test 5: Author cannot vote on own writeup
#############################################################################

my $author_request = TestRequest->new($author_user_hash, { weight => 1 });
$result = $api->cast_vote($author_request, $writeup_id);
is($result->[0], 200, "Author self-vote returns HTTP 200");
is($result->[1]{success}, 0, "Author cannot vote on own writeup");
is($result->[1]{error}, 'You cannot vote on your own writeup', "Correct error for self-vote");

#############################################################################
# Test 6: Successful upvote (+1)
#############################################################################

# Refresh voter hashref to get current votes_left
$voter_user_hash = $DB->getNode("normaluser1", "user");
$voter_request = TestRequest->new($voter_user_hash, { weight => 1 });
$result = $api->cast_vote($voter_request, $writeup_id);
is($result->[0], 200, "Upvote returns HTTP 200");
is($result->[1]{success}, 1, "Upvote succeeds");
is($result->[1]{message}, 'Vote cast successfully', "Success message returned");
is($result->[1]{writeup_id}, $writeup_id, "Writeup ID matches");
is($result->[1]{weight}, 1, "Weight is 1 (upvote)");
ok(defined($result->[1]{votes_remaining}), "Votes remaining is returned");
ok(defined($result->[1]{reputation}), "Reputation is returned");
is($result->[1]{upvotes}, 1, "Upvotes count is 1");
is($result->[1]{downvotes}, 0, "Downvotes count is 0");

# Verify vote was recorded in database
my $vote_record = $DB->sqlSelectHashref(
  '*',
  'vote',
  "voter_user=" . $voter_user_hash->{user_id} . " AND vote_id=$writeup_id"
);
ok($vote_record, "Vote record exists in database");
is($vote_record->{weight}, 1, "Vote weight is 1 in database");

#############################################################################
# Test 7: Cannot vote twice with same weight
#############################################################################

$result = $api->cast_vote($voter_request, $writeup_id);
is($result->[0], 200, "Duplicate vote returns HTTP 200");
is($result->[1]{success}, 0, "Duplicate vote fails");
is($result->[1]{error}, 'You have already cast this vote', "Correct error for duplicate vote");

#############################################################################
# Test 8: Vote swapping (upvote to downvote)
#############################################################################

# Change vote from +1 to -1
$voter_user_hash = $DB->getNode("normaluser1", "user");
$voter_request = TestRequest->new($voter_user_hash, { weight => -1 });
$result = $api->cast_vote($voter_request, $writeup_id);
is($result->[0], 200, "Vote swap returns HTTP 200");
is($result->[1]{success}, 1, "Vote swap succeeds");
is($result->[1]{message}, 'Vote changed successfully', "Vote changed message returned");
is($result->[1]{weight}, -1, "Weight is -1 (downvote)");
is($result->[1]{upvotes}, 0, "Upvotes count is now 0");
is($result->[1]{downvotes}, 1, "Downvotes count is now 1");

# Verify vote was updated in database
$vote_record = $DB->sqlSelectHashref(
  '*',
  'vote',
  "voter_user=" . $voter_user_hash->{user_id} . " AND vote_id=$writeup_id"
);
ok($vote_record, "Vote record still exists after swap");
is($vote_record->{weight}, -1, "Vote weight is -1 after swap");

# Verify votes_remaining didn't change (vote swaps don't consume votes)
my $votes_before_swap = $voter_user_hash->{votesleft};
my $votes_after_swap = $result->[1]{votes_remaining};
is($votes_after_swap, $votes_before_swap, "Votes remaining unchanged after swap");

#############################################################################
# Test 9: Vote swapping back (downvote to upvote)
#############################################################################

$voter_user_hash = $DB->getNode("normaluser1", "user");
$voter_request = TestRequest->new($voter_user_hash, { weight => 1 });
$result = $api->cast_vote($voter_request, $writeup_id);
is($result->[0], 200, "Vote swap back returns HTTP 200");
is($result->[1]{success}, 1, "Vote swap back succeeds");
is($result->[1]{weight}, 1, "Weight is 1 (upvote)");
is($result->[1]{upvotes}, 1, "Upvotes count is 1");
is($result->[1]{downvotes}, 0, "Downvotes count is 0");

#############################################################################
# Test 10: Reputation calculation accuracy
#############################################################################

# Add votes from multiple users and verify reputation is sum of weights
my $user2_hash = $DB->getNode("normaluser3", "user");
ok($user2_hash, "Got second voter user");

# Grant votes if needed
if ($user2_hash->{votesleft} < 5) {
  $DB->sqlUpdate('user', { votesleft => 10 }, "user_id=" . $user2_hash->{user_id});
  $user2_hash = $DB->getNode("normaluser3", "user");
}

# User2 casts upvote
my $user2_request = TestRequest->new($user2_hash, { weight => 1 });
$result = $api->cast_vote($user2_request, $writeup_id);
is($result->[1]{success}, 1, "Second user upvote succeeds");
is($result->[1]{reputation}, 2, "Reputation is 2 after two upvotes");

# User2 changes to downvote
$user2_request = TestRequest->new($user2_hash, { weight => -1 });
$result = $api->cast_vote($user2_request, $writeup_id);
is($result->[1]{success}, 1, "Second user vote change succeeds");
is($result->[1]{reputation}, 0, "Reputation is 0 (1 upvote + 1 downvote)");

# Verify reputation in database matches SUM(weight)
my $db_reputation = $DB->sqlSelect('reputation', 'node', "node_id=$writeup_id");
my $calculated_reputation = $DB->sqlSelect('SUM(weight)', 'vote', "vote_id=$writeup_id") || 0;
is($db_reputation, $calculated_reputation, "Database reputation matches SUM(weight)");
is($db_reputation, 0, "Reputation is 0 in database");

# Add more votes to test larger reputation values
my $user3_hash = $DB->getNode("normaluser4", "user");
if ($user3_hash && $user3_hash->{votesleft} > 0) {
  my $user3_request = TestRequest->new($user3_hash, { weight => 1 });
  $result = $api->cast_vote($user3_request, $writeup_id);
  is($result->[1]{reputation}, 1, "Reputation is 1 after adding third upvote");

  # Verify again
  $db_reputation = $DB->sqlSelect('reputation', 'node', "node_id=$writeup_id");
  $calculated_reputation = $DB->sqlSelect('SUM(weight)', 'vote', "vote_id=$writeup_id") || 0;
  is($db_reputation, $calculated_reputation, "Reputation still matches SUM(weight) after third vote");
}

#############################################################################
# Test 11: Votes are decremented in database after casting a new vote
#############################################################################

{
  # Set up a fresh state - delete existing vote and set known vote count
  $DB->sqlDelete('vote', "voter_user=" . $voter_user_hash->{user_id} . " AND vote_id=$writeup_id");
  $DB->sqlUpdate('user', { votesleft => 10 }, "user_id=" . $voter_user_hash->{user_id});

  # Verify initial state
  my $votes_before = $DB->sqlSelect('votesleft', 'user', "user_id=" . $voter_user_hash->{user_id});
  is($votes_before, 10, "Votes before casting is 10");

  # Clear cache and refresh user hash
  $DB->getCache->removeNode($voter_user_hash);
  $voter_user_hash = $DB->getNode("normaluser1", "user");
  # Manually ensure votesleft reflects DB state (in case getNode uses stale cache)
  $voter_user_hash->{votesleft} = $DB->sqlSelect('votesleft', 'user', "user_id=" . $voter_user_hash->{user_id});

  $voter_request = TestRequest->new($voter_user_hash, { weight => 1 });
  $result = $api->cast_vote($voter_request, $writeup_id);

  is($result->[1]{success}, 1, "Vote decrement test: Vote cast successfully");
  is($result->[1]{votes_remaining}, 9, "Vote decrement test: votes_remaining is 9 in response");

  # Verify the actual database was updated
  my $votes_after = $DB->sqlSelect('votesleft', 'user', "user_id=" . $voter_user_hash->{user_id});
  is($votes_after, 9, "Vote decrement test: votesleft in database was decremented from 10 to 9");
}

#############################################################################
# Test 12: User with no votes remaining
#############################################################################

# Set voter to 0 votes
$DB->sqlUpdate('user', { votesleft => 0 }, "user_id=" . $voter_user_hash->{user_id});
$voter_user_hash->{votesleft} = $DB->sqlSelect('votesleft', 'user', "user_id=" . $voter_user_hash->{user_id});
$voter_request = TestRequest->new($voter_user_hash, { weight => -1 });

# Try to cast a NEW vote (should fail)
# First delete existing vote
$DB->sqlDelete('vote', "voter_user=" . $voter_user_hash->{user_id} . " AND vote_id=$writeup_id");

my $no_votes_request = TestRequest->new($voter_user_hash, { weight => 1 });
$result = $api->cast_vote($no_votes_request, $writeup_id);
is($result->[0], 200, "No votes remaining returns HTTP 200");
is($result->[1]{success}, 0, "Cannot vote with 0 votes remaining");
is($result->[1]{error}, 'You have no votes remaining', "Correct error for no votes");

#############################################################################
# Test 12: Vote swapping doesn't require votes_left
#############################################################################

# Cast initial vote (restore 1 vote temporarily)
$DB->sqlUpdate('user', { votesleft => 1 }, "user_id=" . $voter_user_hash->{user_id});
$voter_user_hash->{votesleft} = $DB->sqlSelect('votesleft', 'user', "user_id=" . $voter_user_hash->{user_id});
$voter_request = TestRequest->new($voter_user_hash, { weight => 1 });
$result = $api->cast_vote($voter_request, $writeup_id);
is($result->[1]{success}, 1, "Initial vote with 1 vote remaining succeeds");

# Set votes to 0 and try to swap (should succeed)
$DB->sqlUpdate('user', { votesleft => 0 }, "user_id=" . $voter_user_hash->{user_id});
$voter_user_hash->{votesleft} = $DB->sqlSelect('votesleft', 'user', "user_id=" . $voter_user_hash->{user_id});
$voter_request = TestRequest->new($voter_user_hash, { weight => -1 });
$result = $api->cast_vote($voter_request, $writeup_id);
is($result->[0], 200, "Vote swap with 0 votes returns HTTP 200");
is($result->[1]{success}, 1, "Vote swap succeeds even with 0 votes remaining");
is($result->[1]{message}, 'Vote changed successfully', "Vote changed message");

#############################################################################
# Cleanup
#############################################################################

# Delete test votes
$DB->sqlDelete('vote', "vote_id=$writeup_id");

# Delete test writeup and e2node
$DB->nukeNode($DB->getNodeById($writeup_id), $author_user_hash);
$DB->nukeNode($DB->getNodeById($e2node_id), $author_user_hash);

done_testing();

=head1 NAME

t/064_vote_api.t - Tests for Everything::API::vote

=head1 DESCRIPTION

Tests for the voting API covering:
- Guest user voting restrictions
- Input validation (writeup_id, weight)
- Author self-vote prevention
- Successful upvote
- Duplicate vote prevention (same weight)
- Vote swapping (changing from upvote to downvote and back)
- Reputation recalculation accuracy (ensures reputation = SUM(weight))
- Votes remaining calculation (swaps don't consume votes)
- Voting with no votes_left (should fail for new votes)
- Vote swapping with no votes_left (should succeed)

Uses real blessed user objects from the database for compatibility
with Application::insertVote().

=head1 TEST COUNT

75+ tests total

=head1 AUTHOR

Everything2 Development Team

=cut
