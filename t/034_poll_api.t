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
use Everything::API::poll;

# Suppress expected warnings throughout the test
$SIG{__WARN__} = sub {
	my $warning = shift;
	warn $warning unless $warning =~ /Could not open log/
	                  || $warning =~ /Use of uninitialized value/;
};

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

#############################################################################
# Test Poll Voting API functionality
#
# These tests verify:
# 1. POST /api/poll/vote - Submit a vote on a poll
# 2. Authorization checks (guest users blocked)
# 3. Validation (poll exists, is open, valid choice)
# 4. Duplicate vote prevention (unless multiple voting allowed)
# 5. Vote counting and result updates
#############################################################################

# Get test users
my $test_user = $DB->getNode("normaluser1", "user");
ok($test_user, "Got test user normaluser1");

my $admin_user = $DB->getNode("root", "user");
ok($admin_user, "Got admin user");

# Check if e2poll type exists
my $e2poll_type = $DB->getType('e2poll');
my $can_test_polls = defined($e2poll_type);

# Create test poll for this test file (self-sufficient, not dependent on seeds)
my $test_poll;
my $test_poll_id;
my $closed_poll;
my $closed_poll_id;

SKIP: {
    skip "e2poll type not available", 50 unless $can_test_polls;

    # Create a current poll for voting tests
    $test_poll_id = $DB->insertNode(
        "Test Poll for Vote API " . time(),
        'e2poll',
        $admin_user,
        {
            poll_author => $admin_user->{node_id},
            question => "What is your test preference?",
            doctext => "Option A\nOption B\nOption C",
            poll_status => 'current',
            totalvotes => 0,
            e2poll_results => '0,0,0',
            multiple => 0,
            is_dailypoll => 0,
            was_dailypoll => 0
        }
    );
    $test_poll = $DB->getNodeById($test_poll_id) if $test_poll_id;
    ok($test_poll, "Created test poll with 'current' status");

    # Create a closed poll for closed-poll tests
    $closed_poll_id = $DB->insertNode(
        "Test Closed Poll " . time(),
        'e2poll',
        $admin_user,
        {
            poll_author => $admin_user->{node_id},
            question => "This poll is closed?",
            doctext => "Yes\nNo",
            poll_status => 'closed',
            totalvotes => 5,
            e2poll_results => '3,2',
            multiple => 0,
            is_dailypoll => 0,
            was_dailypoll => 0
        }
    );
    $closed_poll = $DB->getNodeById($closed_poll_id) if $closed_poll_id;
    ok($closed_poll, "Created test poll with 'closed' status");

}  # End initial SKIP block for poll creation

# Helper: Create a mock request object
package MockRequest {
    sub new {
        my ($class, %args) = @_;
        return bless \%args, $class;
    }
    sub user { return $_[0]->{user} }
    sub POSTDATA {
        my $self = shift;
        return undef unless $self->{_postdata};
        require JSON;
        return JSON->new->encode($self->{_postdata});
    }
    sub JSON_POSTDATA { return $_[0]->{_postdata} }
}

# Helper: Create a mock user object
package MockUser {
    sub new {
        my ($class, %args) = @_;
        my $self = {
            node_id => $args{node_id},
            title => $args{title},
            is_guest_flag => $args{is_guest_flag} // 0,
            is_admin_flag => $args{is_admin_flag} // 0,
            VARS => $args{VARS} // {},
            NODEDATA => $args{NODEDATA},
        };
        return bless $self, $class;
    }
    sub VARS { return $_[0]->{VARS} }
    sub node_id { return $_[0]->{node_id} }
    sub title { return $_[0]->{title} }
    sub is_admin { return $_[0]->{is_admin_flag} // 0 }
}

package main;

# Create API instance
my $api = Everything::API::poll->new();
ok($api, "Created poll API instance");

# Skip all remaining tests if we couldn't create test polls
SKIP: {
    skip "Test poll not available", 40 unless $test_poll;

#############################################################################
# Test 1: Authorization - guest user blocked
#############################################################################

subtest 'Authorization: guest user cannot vote' => sub {
    plan tests => 2;

    # Create mock guest user
    my $mock_user = MockUser->new(
        node_id => 0,
        title => 'Guest User',
        is_guest_flag => 1,
    );

    my $mock_request = MockRequest->new(
        user => $mock_user,
        _postdata => {
            poll_id => $test_poll->{node_id},
            choice => 0,
        },
    );

    my $result = $api->submit_vote($mock_request);
    is($result->[0], 403, "Vote returns HTTP 403 for guest");
    like($result->[1]{error}, qr/must be logged in/i, "Error message mentions login required");
};

#############################################################################
# Test 2: Validation - missing required fields
#############################################################################

subtest 'Validation: missing required fields' => sub {
    plan tests => 6;

    # Create mock user
    my $mock_user = MockUser->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
    );

    # Missing poll_id
    my $mock_request1 = MockRequest->new(
        user => $mock_user,
        _postdata => { choice => 0 },
    );
    my $result1 = $api->submit_vote($mock_request1);
    is($result1->[0], 400, "Returns HTTP 400 when missing poll_id");
    like($result1->[1]{error}, qr/required fields/i, "Error mentions required fields");

    # Missing choice
    my $mock_request2 = MockRequest->new(
        user => $mock_user,
        _postdata => { poll_id => $test_poll->{node_id} },
    );
    my $result2 = $api->submit_vote($mock_request2);
    is($result2->[0], 400, "Returns HTTP 400 when missing choice");

    # Invalid choice (not a number)
    my $mock_request3 = MockRequest->new(
        user => $mock_user,
        _postdata => {
            poll_id => $test_poll->{node_id},
            choice => "invalid",
        },
    );
    my $result3 = $api->submit_vote($mock_request3);
    is($result3->[0], 400, "Returns HTTP 400 for non-numeric choice");

    # Invalid choice (out of range)
    my $mock_request4 = MockRequest->new(
        user => $mock_user,
        _postdata => {
            poll_id => $test_poll->{node_id},
            choice => 999,
        },
    );
    my $result4 = $api->submit_vote($mock_request4);
    is($result4->[0], 400, "Returns HTTP 400 for choice out of range");
    like($result4->[1]{error}, qr/Invalid choice/i, "Error mentions invalid choice");
};

#############################################################################
# Test 3: Validation - poll not found
#############################################################################

subtest 'Validation: poll not found' => sub {
    plan tests => 2;

    my $mock_user = MockUser->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
    );

    my $mock_request = MockRequest->new(
        user => $mock_user,
        _postdata => {
            poll_id => 99999999,
            choice => 0,
        },
    );

    my $result = $api->submit_vote($mock_request);
    is($result->[0], 404, "Returns HTTP 404 for nonexistent poll");
    like($result->[1]{error}, qr/not found/i, "Error mentions not found");
};

#############################################################################
# Test 4: Successful vote submission
#############################################################################

subtest 'Successful vote submission' => sub {
    plan tests => 11;

    # Use a different user who hasn't voted yet
    my $voter = $DB->getNode("normaluser21", "user");

    # Clean up any existing votes for this user using admin API
    my $admin = $DB->getNode("root", "user");
    my $admin_mock = MockUser->new(
        node_id => $admin->{node_id},
        title => $admin->{title},
        is_admin_flag => 1,
    );
    my $cleanup_request = MockRequest->new(
        user => $admin_mock,
        _postdata => {
            poll_id => $test_poll->{node_id},
            voter_user => $voter->{node_id},
        },
    );
    $api->delete_vote($cleanup_request);

    # Refresh poll data after cleanup
    $test_poll = $DB->getNodeById($test_poll->{node_id});

    my $mock_user = MockUser->new(
        node_id => $voter->{node_id},
        title => $voter->{title},
    );

    # Get initial vote count
    my $initial_votes = $test_poll->{totalvotes};

    my $mock_request = MockRequest->new(
        user => $mock_user,
        _postdata => {
            poll_id => $test_poll->{node_id},
            choice => 0,  # Vote for first option
        },
    );

    my $result = $api->submit_vote($mock_request);
    is($result->[0], 200, "Vote returns HTTP 200 on success");
    ok($result->[1]{success}, "Response indicates success");
    is($result->[1]{poll}{userVote}, 0, "Response includes user's vote");
    is($result->[1]{poll}{node_id}, $test_poll->{node_id}, "Response includes poll ID");
    ok($result->[1]{poll}{totalvotes} > $initial_votes, "Total votes increased");

    # Verify vote was recorded in database
    my $recorded_vote = $DB->sqlSelect(
        'choice',
        'pollvote',
        "voter_user=" . $voter->{node_id} . " AND pollvote_id=" . $test_poll->{node_id}
    );
    is($recorded_vote, 0, "Vote was recorded in database");

    # Verify poll was updated
    my $updated_poll = $DB->getNodeById($test_poll->{node_id});
    my @results = split ',', $updated_poll->{e2poll_results};
    ok($results[0] > 0, "Vote count for option 0 was incremented");
    ok($updated_poll->{totalvotes} > $initial_votes, "Poll total votes was incremented");

    # Verify response structure
    ok(exists $result->[1]{poll}{options}, "Response includes poll options");
    ok(ref $result->[1]{poll}{options} eq 'ARRAY', "Poll options is an array");
    ok(scalar(@{$result->[1]{poll}{options}}) > 0, "Poll has options");
};

#############################################################################
# Test 5: Prevent duplicate voting
#############################################################################

subtest 'Prevent duplicate voting' => sub {
    plan tests => 3;

    # First, have normaluser1 vote on our test poll
    my $first_vote_user = MockUser->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
    );

    my $first_vote_request = MockRequest->new(
        user => $first_vote_user,
        _postdata => {
            poll_id => $test_poll->{node_id},
            choice => 0,
        },
    );
    $api->submit_vote($first_vote_request);  # Cast first vote

    # Now try to vote again with the same user
    my $mock_user = MockUser->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
    );

    my $mock_request = MockRequest->new(
        user => $mock_user,
        _postdata => {
            poll_id => $test_poll->{node_id},
            choice => 1,
        },
    );

    my $result = $api->submit_vote($mock_request);
    is($result->[0], 400, "Returns HTTP 400 for duplicate vote");
    like($result->[1]{error}, qr/already voted/i, "Error mentions already voted");
    ok(exists $result->[1]{previous_vote}, "Response includes previous vote");
};

#############################################################################
# Test 6: Cannot vote on closed poll
#############################################################################

subtest 'Cannot vote on closed poll' => sub {
    plan tests => 2;

    SKIP: {
        skip "No closed poll available", 2 unless $closed_poll;

        my $voter = $DB->getNode("normaluser3", "user");
        my $mock_user = MockUser->new(
            node_id => $voter->{node_id},
            title => $voter->{title},
        );

        my $mock_request = MockRequest->new(
            user => $mock_user,
            _postdata => {
                poll_id => $closed_poll->{node_id},
                choice => 0,
            },
        );

        my $result = $api->submit_vote($mock_request);
        is($result->[0], 400, "Returns HTTP 400 for closed poll");
        like($result->[1]{error}, qr/not open/i, "Error mentions poll not open");
    }
};

}  # End main SKIP block

#############################################################################
# Cleanup - delete test polls
#############################################################################

if ($test_poll_id) {
    $DB->sqlDelete('pollvote', "pollvote_id=$test_poll_id");
    my $poll = $DB->getNodeById($test_poll_id);
    $DB->nukeNode($poll, -1) if $poll;
}

if ($closed_poll_id) {
    $DB->sqlDelete('pollvote', "pollvote_id=$closed_poll_id");
    my $poll = $DB->getNodeById($closed_poll_id);
    $DB->nukeNode($poll, -1) if $poll;
}

done_testing();
